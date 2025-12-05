# Advent of FPGA 2025

Implementing [Advent of Code 2025](https://adventofcode.com/2025) puzzles as synthesizable hardware using [Hardcaml](https://github.com/janestreet/hardcaml).

Part of the [Jane Street Advent of FPGA Challenge](https://blog.janestreet.com/advent-of-fpga-challenge-2025/).

## Prerequisites

- [opam](https://opam.ocaml.org/) (OCaml package manager)
- macOS or Linux

## Setup (First Time)

```bash
# Install opam if needed
brew install opam

# Create project-specific switch with OCaml 5.2.0
opam switch create advent-fpga 5.2.0

# Install required packages
opam install -y hardcaml hardcaml_waveterm ppx_hardcaml hardcaml_verify
```

## Build & Run

```bash
# Build all solutions
opam exec --switch=advent-fpga -- dune build

# Run all tests (verifies hardware matches software reference)
opam exec --switch=advent-fpga -- dune runtest

# Run a specific day
opam exec --switch=advent-fpga -- dune exec hardcaml/day01/solution.exe -- common/test_vectors/day01.txt
```

## Project Structure

```
advent-of-fpga-2025/
├── dune-project          # Dune build config
├── dune                   # Top-level test targets
├── hardcaml/
│   └── day01/
│       ├── dune          # Day-specific build config
│       └── solution.ml   # Hardware implementation + simulation
├── common/
│   └── test_vectors/     # Puzzle inputs
└── docs/
    └── TECHNICAL_NOTES.md
```

## Solutions

| Day | Puzzle | Part 1 | Part 2 | Notes |
|-----|--------|--------|--------|-------|
| 01  | Safe Dial | 1076 | 6379 | Division by multiplication-reciprocal |

## Goals

- Synthesizable RTL designs (no simulation-only constructs)
- Formal verification with hardcaml_verify
- Learn Hardcaml patterns and idioms

**Note**: This is an R&D project exploring AI-assisted hardware design. Not intended for contest submission.
