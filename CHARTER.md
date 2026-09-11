# Physical implementation and design feasibility: team charter

## Purpose

Connect logical hardware design to the realities of implementing a chip. The team investigates how technology, constraints and implementation choices affect feasibility, performance, power, area and confidence in the physical realization of the accelerator.

Physical implementation informs design choices long before a final chip exists. Studies of constraints, timing, storage options, synthesis behavior or implementation methodology can expose important tradeoffs. The team’s role includes research and interpretation as well as operating implementation tools.

## Responsibilities

### Implementation assumptions

Understand and explain target technology, libraries, tools and constraints relevant to the design. Distinguish available resources, exploratory assumptions and decisions the project has actually adopted.

### Logical-to-physical tradeoffs

Investigate how RTL and architectural choices influence area, timing, power and physical organization. Feed evidence back to design teams in terms they can use.

### Implementation methods and evidence

Develop suitable synthesis, timing, equivalence and physical implementation approaches as the project needs them. Explain what a flow and its checks do and do not establish.

### Physical-design understanding

Preserve constraint rationale, experiments, results and interpretation so members can build knowledge rather than inherit opaque scripts or unexplained reports.

## Boundaries and shared decisions

Physical-design owns ASIC implementation methods and interpretation of their results. RTL teams own functional block design; SoC owns hardware composition; architecture helps interpret system tradeoffs; verification contributes functional confidence. FPGA results describe a different implementation target. Physical-design can propose changes based on evidence, with behavior or shared-interface changes agreed with the responsible teams.

## Member autonomy

Members may study timing methodology, compare synthesis outcomes, examine storage implementation choices, investigate constraints, build a flow, analyze reports or create educational material. Tools and targets follow the team’s questions and available access. Choosing a technology, adding external commitments or changing a shared design constraint is a collaborative decision. The charter does not set a tapeout date or equate a starter flow with sign-off readiness.

## Collaboration

| Partners | Shared concerns |
|---|---|
| RTL teams and soc | Exchange design intent, clock/reset assumptions and implementation feedback to connect measured issues to useful design choices. |
| architecture and ml-models | Relate physical costs and constraints to architectural estimates and workload needs without implying that an isolated metric determines the whole design. |
| verification and accelerator | Clarify the scope of implementation evidence and how it fits with functional and system-level claims. |

## Possible directions

Members might investigate why a path is critical, compare alternative datapaths after synthesis, study constraint quality, explore a floorplanning idea, examine memory options or explain an implementation report. A careful analysis can be valuable before a complete flow is practical.

## What progress means

Progress means implementation assumptions are explicit, results can be interpreted and design choices become better informed. A discovered constraint problem, a reproducible comparison or an explanation of an unavailable technology option is useful alongside more complete implementation work.

Leads help members interpret this purpose, find collaborators, access resources
and share what they learn. Members choose their questions and contributions.
Research, design reasoning, experiments, implementation, documentation and
teaching can all advance the charter; success is not measured by the number of
code changes or completed tickets.

The team can revise this charter as its understanding evolves. Changes to a
shared boundary or commitment are discussed with the teams affected by them.
The [objectives](OBJECTIVES.md) describe durable outcomes, and the
[repository structure](README.md#repository-structure) provides places to develop
work without specifying a mandatory project or sequence.
