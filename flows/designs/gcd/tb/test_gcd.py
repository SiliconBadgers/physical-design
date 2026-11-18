# File:        test_gcd.py
# Author:      Isaac Hagedorn
# Date:        2026-10-08
# Description: cocotb tests for the ORFS gcd unit. Runs on the RTL (make sim) and the netlist (make gls).

import math
import random

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge

CLK_NS = 10
MAX_CYCLES = 70_000  # gcd(65535, 1) takes ~65535 steps


async def reset(dut):
    dut.req_val.value = 0
    dut.req_msg.value = 0
    dut.resp_rdy.value = 0
    dut.reset.value = 1
    for _ in range(3):
        await RisingEdge(dut.clk)
    await FallingEdge(dut.clk)
    dut.reset.value = 0


async def compute(dut, a, b):
    """Send one request and return the response, or fail on timeout."""
    # Request: driven at a falling edge, held until accepted.
    dut.req_msg.value = (a << 16) | b
    dut.req_val.value = 1
    for _ in range(MAX_CYCLES):
        await RisingEdge(dut.clk)
        if int(dut.req_rdy.value) == 1:
            break
    else:
        raise AssertionError(f"gcd({a}, {b}): request never accepted")
    await FallingEdge(dut.clk)
    dut.req_val.value = 0

    # Response: always ready, wait for resp_val.
    dut.resp_rdy.value = 1
    for _ in range(MAX_CYCLES):
        await RisingEdge(dut.clk)
        if int(dut.resp_val.value) == 1:
            result = int(dut.resp_msg.value)
            break
    else:
        raise AssertionError(f"gcd({a}, {b}): no response after {MAX_CYCLES} cycles")
    await FallingEdge(dut.clk)
    dut.resp_rdy.value = 0
    return result


@cocotb.test()
async def test_directed(dut):
    """Hand-picked cases, including zeros and the slowest input."""
    cocotb.start_soon(Clock(dut.clk, CLK_NS, unit="ns").start())
    await reset(dut)
    cases = [(27, 15), (15, 27), (7, 7), (1, 1), (0, 5), (5, 0), (0, 0),
             (0xFFFF, 0xFFFF), (0xFFFF, 1), (48, 180), (17, 13), (1024, 768)]
    for a, b in cases:
        got = await compute(dut, a, b)
        assert got == math.gcd(a, b), f"gcd({a}, {b}) = {got}, expected {math.gcd(a, b)}"


@cocotb.test()
async def test_random(dut):
    """Random pairs with a shared factor."""
    cocotb.start_soon(Clock(dut.clk, CLK_NS, unit="ns").start())
    await reset(dut)
    rng = random.Random(2026)
    for _ in range(40):
        k = rng.randint(1, 255)
        a = k * rng.randint(0, 0xFFFF // k)
        b = k * rng.randint(0, 0xFFFF // k)
        got = await compute(dut, a, b)
        assert got == math.gcd(a, b), f"gcd({a}, {b}) = {got}, expected {math.gcd(a, b)}"
