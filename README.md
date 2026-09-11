# Physical implementation and design feasibility

Connect logical hardware design to the realities of implementing a chip. The team investigates how technology, constraints and implementation choices affect feasibility, performance, power, area and confidence in the physical realization of the accelerator.

## Read the charter

- [CHARTER.md](CHARTER.md): purpose, responsibilities, boundaries, member autonomy and collaboration.
- [OBJECTIVES.md](OBJECTIVES.md): high-level outcomes that members can choose how to advance.
- [SETUP.md](SETUP.md): optional technical setup and the scope of any existing example.

## Choosing a contribution

Members choose their work in conversation with the charter and their interests.
A contribution can be a research question, a design study, an experiment, an
implementation, a useful explanation or teaching material. Leads help connect
people, questions and evidence. Shared interfaces and commitments are discussed
with the teams that depend on them.

The scaffold supplies places for that work. It does not specify a backlog,
required first project, milestone sequence or personal assignment.

## Repository structure

| Location | Purpose |
|---|---|
| [docs/](docs/README.md) | Design explanations, proposals, reviews, decisions and learning material. Let the content evolve with the team’s questions; link research and experiment evidence where useful. |
| [research/](research/README.md) | Literature notes, surveys, analytical studies and comparisons relevant to the charter. Explain the question, sources, interpretation and remaining uncertainty in a form that suits the work. |
| [experiments/](experiments/README.md) | Exploratory studies, prototypes and experiment narratives. Make the question and interpretation understandable; preserve the context needed to revisit a result. These artifacts need not be production implementations. |
| [flows/](flows/README.md) | Implementation methods and scripts developed for the questions the team chooses to investigate. |
| [constraints/](constraints/README.md) | Clock, IO and technology assumptions used in implementation studies. |
| [reports/](reports/README.md) | Curated results and their interpretation; large raw tool outputs belong in build. |

The team may extend this structure as useful. Existing example entry points stay
in their current locations, described in [SETUP.md](SETUP.md).

## Current material

The charter, documentation and directory scaffold are present. No component implementation or runnable component test is supplied yet. The team chooses what work to undertake.

Existing code is optional material for learning or experimentation. Its behavior
and tests describe that example and do not select the team’s future design.
Reading or contributing to the charter, research and design documentation needs
no tool installation.

This is the [SiliconBadgers/physical-design](https://github.com/SiliconBadgers/physical-design) team repository.
The [organization guide](https://github.com/SiliconBadgers/accelerator/blob/main/docs/TEAM_GUIDE.md)
and [repository map](https://github.com/SiliconBadgers/accelerator/blob/main/docs/REPOSITORIES.md)
explain how the teams connect.
