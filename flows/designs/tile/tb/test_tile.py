# File:        test_tile.py
# Author:      Isaac Hagedorn
# Date:        2026-10-08
# Description: cocotb tests for sb_systolic_tile against a Python model of C = A x W. Runs on the RTL (make sim) and the netlist (make gls).

import os
import random

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, ReadOnly

CLK_NS = 10
TIMEOUT_CYCLES = 20_000


def design_params() -> dict:
    out = {}
    for item in os.environ.get("SB_DESIGN_PARAMS", "").split():
        k, _, v = item.partition("=")
        out[k] = int(v)
    return out


class Tile:
    def __init__(self, dut):
        self.dut = dut
        p = design_params()
        self.data_w = len(dut.w_data)
        self.acc_w = len(dut.res_data)
        self.k_w = len(dut.cfg_k_len)
        self.n_rows = len(dut.act_data) // self.data_w
        col_w = len(dut.w_addr) - self.k_w
        self.n_cols = p.get("N_COLS", 2 ** col_w)
        self.depth = 2 ** self.k_w

    def signed(self, value: int, bits: int) -> int:
        value &= (1 << bits) - 1
        return value - (1 << bits) if value >> (bits - 1) else value

    async def reset(self):
        d = self.dut
        for name in ("w_we", "w_addr", "w_data", "act_valid", "act_data",
                     "res_sel", "res_ready", "cfg_k_len"):
            getattr(d, name).value = 0
        d.rst_n.value = 0
        for _ in range(3):
            await RisingEdge(d.clk)
        await FallingEdge(d.clk)
        d.rst_n.value = 1
        for _ in range(3):              # the reset synchronizer needs 2 cycles
            await FallingEdge(d.clk)

    async def load_weights(self, w):
        """w[k][c]: one write per cycle, address {c, k}."""
        d = self.dut
        for k in range(len(w)):
            for c in range(self.n_cols):
                d.w_we.value = 1
                d.w_addr.value = (c << self.k_w) | k
                d.w_data.value = w[k][c] & ((1 << self.data_w) - 1)
                await FallingEdge(d.clk)
        d.w_we.value = 0

    async def stream(self, a, stall_prob=0.0):
        """a[r][k]: one beat per accepted cycle, with optional random stalls."""
        d = self.dut
        k_len = len(a[0])
        d.cfg_k_len.value = k_len - 1
        k = 0
        for _ in range(TIMEOUT_CYCLES):
            if k == k_len:
                break
            if random.random() < stall_prob:
                d.act_valid.value = 0
            else:
                beat = 0
                for r in range(self.n_rows):
                    beat |= (a[r][k] & ((1 << self.data_w) - 1)) << (r * self.data_w)
                d.act_data.value = beat
                d.act_valid.value = 1
            await RisingEdge(d.clk)
            if int(d.act_valid.value) and int(d.act_ready.value):
                k += 1
            await FallingEdge(d.clk)
        else:
            raise AssertionError("activation stream not accepted (act_ready stuck low?)")
        d.act_valid.value = 0

    async def read_results(self, order):
        """Read every PE once, in the given order of res_sel values."""
        d = self.dut
        got = {}
        for sel in order:
            d.res_sel.value = sel
            d.res_ready.value = 1
            for _ in range(TIMEOUT_CYCLES):
                await RisingEdge(d.clk)
                if int(d.res_valid.value) and int(d.res_ready.value):
                    got[sel] = self.signed(int(d.res_data.value), self.acc_w)
                    break
            else:
                raise AssertionError(f"res_valid never came for res_sel={sel}")
            await FallingEdge(d.clk)
        d.res_ready.value = 0
        return got

    async def run_tile(self, a, w, order=None, stall_prob=0.0):
        await self.load_weights(w)
        await self.stream(a, stall_prob)
        n = self.n_rows * self.n_cols
        got = await self.read_results(order if order is not None else list(range(n)))
        for r in range(self.n_rows):
            for c in range(self.n_cols):
                want = sum(a[r][k] * w[k][c] for k in range(len(w)))
                sel = r * self.n_cols + c
                assert got[sel] == want, (
                    f"C[{r}][{c}] = {got[sel]}, expected {want} "
                    f"(K={len(w)}, ACC_W={self.acc_w})")


def rand_int8(t: Tile):
    lo, hi = -(1 << (t.data_w - 1)), (1 << (t.data_w - 1)) - 1
    return random.randint(lo, hi)


async def start(dut) -> Tile:
    cocotb.start_soon(Clock(dut.clk, CLK_NS, unit="ns").start())
    t = Tile(dut)
    await t.reset()
    return t


@cocotb.test()
async def test_small(dut):
    """A 4-deep tile with known values, results read in order."""
    t = await start(dut)
    k = 4
    a = [[(r + 1) * (kk + 1) for kk in range(k)] for r in range(t.n_rows)]
    w = [[(c - 1) * (kk + 2) for c in range(t.n_cols)] for kk in range(k)]
    await t.run_tile(a, w)


@cocotb.test()
async def test_random_with_stalls(dut):
    """Random int8 data, random gaps in the activation stream, random readout order."""
    random.seed(1234)
    t = await start(dut)
    for k in (1, 7, 32):
        a = [[rand_int8(t) for _ in range(k)] for _ in range(t.n_rows)]
        w = [[rand_int8(t) for _ in range(t.n_cols)] for _ in range(k)]
        order = list(range(t.n_rows * t.n_cols))
        random.shuffle(order)
        await t.run_tile(a, w, order=order, stall_prob=0.3)


@cocotb.test()
async def test_worst_case_accumulation(dut):
    """Largest sums: full-depth K with most-negative and mixed-sign operands."""
    t = await start(dut)
    k = t.depth
    most_neg = -(1 << (t.data_w - 1))
    a = [[most_neg] * k for _ in range(t.n_rows)]
    w = [[most_neg] * t.n_cols for _ in range(k)]
    await t.run_tile(a, w)
    w = [[(1 << (t.data_w - 1)) - 1] * t.n_cols for _ in range(k)]   # most_neg * max_pos
    await t.run_tile(a, w)
