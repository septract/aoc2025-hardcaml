# Advent of FPGA 2025 - Technical Setup Guide

## Challenge Overview
The Jane Street [Advent of FPGA Challenge 2025](https://blog.janestreet.com/advent-of-fpga-challenge-2025/) asks participants to implement Advent of Code puzzles as **synthesizable hardware designs**.

**Key insight**: Designs only need to be synthesizable - no actual FPGA hardware required. All work can be done on macOS with simulation tools.

**Deadline**: January 16, 2026

---

# HDL Language Comparison

## Quick Reference

| Language | Paradigm | Learning Curve | macOS Support | Simulation Speed | Bonus |
|----------|----------|----------------|---------------|------------------|-------|
| **Verilog** | Imperative | Medium | Excellent | Fast (Verilator) | - |
| **Amaranth** | Python DSL | Low | Excellent | Medium | - |
| **Hardcaml** | Functional | High | Good | Medium | T-shirt! |
| **Chisel** | Scala DSL | Medium-High | Good | Fast | - |
| **VHDL** | Imperative | Medium | Good | Medium | - |

---

## Option 1: Verilog

### Overview
Industry-standard HDL. Most tutorials, examples, and Stack Overflow answers exist for Verilog. If you've done any digital design coursework, you've likely seen Verilog.

### Tradeoffs

| Pros | Cons |
|------|------|
| Massive documentation & examples | Verbose - lots of boilerplate |
| Industry standard | No type safety - bit-width bugs common |
| Fast simulation with Verilator | Manual instantiation of repeated logic |
| Direct control over hardware | Easy to write non-synthesizable code |

### When to Choose
- You have prior Verilog/digital design experience
- You want maximum available resources/tutorials
- You prefer explicit control over abstraction

### Installation (macOS)

```bash
# Install Icarus Verilog (simulator) and GTKWave (waveform viewer)
brew install icarus-verilog gtkwave

# Optional: Verilator for faster simulation (requires more setup on Apple Silicon)
brew install verilator

# Verify installation
iverilog -V
```

### Verification Test
```bash
# Create test file
cat > hello.v << 'EOF'
module hello;
  initial begin
    $display("Hello, FPGA!");
    $finish;
  end
endmodule
EOF

# Compile and run
iverilog -o hello hello.v && vvp hello
# Should print: Hello, FPGA!
```

### Typical Workflow
```bash
iverilog -o sim testbench.v design.v    # Compile
vvp sim                                  # Run simulation
gtkwave dump.vcd                         # View waveforms
```

---

## Option 2: Amaranth (Python HDL)

### Overview
Modern Python-based HDL. Write Python code that generates hardware. Includes a built-in simulator - no external tools needed for basic work.

### Tradeoffs

| Pros | Cons |
|------|------|
| Python syntax - familiar to most devs | Smaller community than Verilog |
| Built-in simulator (no dependencies) | Less documentation/examples |
| Type-safe bit widths | Generated Verilog can be hard to read |
| Pythonic abstractions (loops, classes) | Debugging requires understanding both layers |

### When to Choose
- You're a Python developer
- You want the fastest path to working simulation
- You prefer high-level abstractions

### Installation (macOS)

```bash
# Ensure Python 3.9+
python3 --version

# Install Amaranth and optional Yosys backend
pip install amaranth
pip install amaranth-yosys  # Optional: for synthesis checks

# For waveform viewing
brew install gtkwave
# Or use: pip install surfer
```

### Verification Test
```python
# save as hello.py
from amaranth import *
from amaranth.sim import Simulator

class Counter(Elaboratable):
    def __init__(self, width):
        self.count = Signal(width)

    def elaborate(self, platform):
        m = Module()
        m.d.sync += self.count.eq(self.count + 1)
        return m

# Simulate
dut = Counter(8)
sim = Simulator(dut)
sim.add_clock(1e-6)

def testbench():
    for _ in range(10):
        yield
        print(f"Count: {(yield dut.count)}")

sim.add_process(testbench)
sim.run()
```

```bash
python3 hello.py
```

### Typical Workflow
```python
# Design in Python
# Simulate with built-in simulator
# Export to Verilog: output = verilog.convert(design)
```

---

## Option 3: Hardcaml (OCaml HDL) ⭐ CHOSEN - T-SHIRT BONUS + FORMAL VERIFICATION

### Overview
Jane Street's in-house HDL. Functional programming approach to hardware design. **Completing any puzzle in Hardcaml wins you a t-shirt.**

### Tradeoffs

| Pros | Cons |
|------|------|
| **Free t-shirt for 1 puzzle!** | Must learn OCaml |
| Powerful functional abstractions | Smaller ecosystem |
| Strong type system catches errors | Steeper learning curve |
| Native simulation in OCaml | Less beginner documentation |
| Jane Street's production tool | Unfamiliar syntax for most |
| **Best formal verification** | |

### When to Choose
- You want the t-shirt (only need to solve ONE puzzle)
- You know/want to learn OCaml or functional programming
- You appreciate strong type systems
- You want to use what Jane Street uses internally
- **You want native formal verification**

### Installation (macOS)

```bash
# Install opam (OCaml package manager)
brew install opam

# Initialize opam (first time only - takes a few minutes)
opam init -y
eval $(opam env)

# Add Jane Street's bleeding edge repo for latest Hardcaml
opam repo add janestreet-bleeding https://ocaml.janestreet.com/opam-repository

# Install Hardcaml and tools (including formal verification)
opam install -y hardcaml hardcaml_waveterm ppx_hardcaml hardcaml_verify

# Verify
ocaml -version
```

**Note**: First-time opam init compiles OCaml from source (~5-10 min).

### Verification Test
```ocaml
(* save as hello.ml *)
open Hardcaml

let () =
  let a = Signal.of_int ~width:8 42 in
  let b = Signal.of_int ~width:8 10 in
  let sum = Signal.(a +: b) in
  print_endline ("Sum width: " ^ Int.to_string (Signal.width sum))
```

```bash
# Compile and run
ocamlfind ocamlopt -package hardcaml -linkpkg hello.ml -o hello
./hello
```

### Typical Workflow
```ocaml
(* 1. Define circuit as OCaml module *)
(* 2. Simulate using Hardcaml_waveterm *)
(* 3. Export: Rtl.print Verilog.output circuit *)
```

---

## Option 4: Chisel (Scala HDL)

### Overview
Scala-based HDL from UC Berkeley. Powers RISC-V development. Modern abstractions with strong tooling.

### Tradeoffs

| Pros | Cons |
|------|------|
| Modern language features | Requires JVM + Scala + sbt |
| Good abstractions | Heavier toolchain |
| Active academic community | Build times can be slow |
| Powers RISC-V ecosystem | Scala learning curve |

### When to Choose
- You know Scala/JVM
- You want industry-relevant experience (RISC-V)
- You prefer object-oriented + functional mix

### Installation (macOS)

```bash
# Install JDK and sbt
brew install openjdk sbt

# Add to shell profile
echo 'export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

# Install Verilator for simulation
brew install verilator

# Verify
java -version
sbt --version
```

### Project Setup
```bash
# Clone Chisel template
git clone https://github.com/chipsalliance/chisel-template.git
cd chisel-template
sbt test  # Runs example tests
```

---

## Option 5: VHDL

### Overview
The "other" industry HDL. More verbose than Verilog but stricter typing. Common in aerospace/defense.

### Tradeoffs

| Pros | Cons |
|------|------|
| Stricter than Verilog | Very verbose |
| Strong typing | Less popular in startups/tech |
| Good for safety-critical | Fewer modern tutorials |

### Installation (macOS)

```bash
# Install GHDL (VHDL simulator)
brew install ghdl

# Verify
ghdl --version
```

---

# Formal Verification Options

## Quick Comparison

| HDL | Formal Tool | Verification Type | macOS Support | Ease of Use |
|-----|-------------|-------------------|---------------|-------------|
| **Hardcaml** | hardcaml_verify | SAT, BMC, LTL (NuSMV) | Native | Best |
| **Verilog** | SymbiYosys | SAT/SMT, BMC | Via OSS CAD Suite | Good |
| **Amaranth** | SymbiYosys (export) | SAT/SMT, BMC | Via OSS CAD Suite | Medium |
| **Chisel** | ChiselTest + Z3 | Assertions | Via JVM | Medium |
| **VHDL** | GHDL + SymbiYosys | SAT/SMT | Limited | Poor |

---

## Option 1: Hardcaml + hardcaml_verify ⭐ BEST FOR FORMAL

### Overview
**hardcaml_verify** is Jane Street's native formal verification library. It's the most integrated formal verification experience of all options.

### Capabilities
- **SAT-based equivalence checking** - Prove two combinational circuits are identical
- **Bounded Model Checking (BMC)** - Verify sequential circuits up to N cycles
- **LTL assertions via NuSMV** - Prove temporal logic properties
- **Property-based testing** - QuickCheck-style random testing

### Installation
```bash
opam install hardcaml_verify
```

### Example Usage
```ocaml
open Hardcaml
open Hardcaml_verify

(* Prove two adder implementations are equivalent *)
let prove_equivalence () =
  let a = Signal.input "a" 8 in
  let b = Signal.input "b" 8 in
  let impl1 = Signal.(a +: b) in
  let impl2 = my_custom_adder a b in
  Sat.prove_equivalence impl1 impl2
```

### Why Best for Formal
- Native OCaml integration (no subprocess/file conversion)
- Same language for design and verification
- Industrial-strength (used at Jane Street)
- Type-safe property specifications

---

## Option 2: SymbiYosys (Verilog/Amaranth)

### Overview
Open-source formal verification frontend for Yosys. Works with Verilog directly or with Amaranth (export to Verilog).

### Capabilities
- **Bounded Model Checking** - Prove properties hold for N cycles
- **K-induction** - Prove properties hold for all time (if inductive)
- **Cover statements** - Prove states are reachable
- **Assertion checking** - `assert`, `assume`, `cover` properties

### Installation (macOS)
```bash
# Install OSS CAD Suite (includes Yosys + SymbiYosys + solvers)
brew install --cask oss-cad-suite

# Or via pip (Yosys only, need solvers separately)
pip install yowasp-yosys

# Verify
sby --help
```

### Verilog Formal Properties
```verilog
module counter (
    input clk,
    input rst,
    output reg [7:0] count
);
    always @(posedge clk)
        if (rst) count <= 0;
        else count <= count + 1;

    // Formal properties (only compiled with -DFORMAL)
    `ifdef FORMAL
        // Count should never exceed 255 (trivially true for 8-bit)
        always @(posedge clk)
            assert(count <= 255);

        // After reset, count should be 0
        always @(posedge clk)
            if ($past(rst)) assert(count == 0);

        // Prove we can reach count == 100
        always @(posedge clk)
            cover(count == 100);
    `endif
endmodule
```

### SymbiYosys Configuration (.sby file)
```
[options]
mode bmc
depth 20

[engines]
smtbmc z3

[script]
read -formal counter.v
prep -top counter

[files]
counter.v
```

### Run Verification
```bash
sby -f counter.sby
```

---

## Option 3: Amaranth + SymbiYosys

### Overview
Amaranth can export to Verilog with formal annotations, then use SymbiYosys.

### Workflow
1. Write design in Amaranth Python
2. Add `Assert`, `Assume`, `Cover` statements
3. Export to Verilog with formal annotations
4. Run SymbiYosys on generated Verilog

### Example
```python
from amaranth import *
from amaranth.asserts import Assert, Assume, Cover

class VerifiedCounter(Elaboratable):
    def elaborate(self, platform):
        m = Module()
        count = Signal(8)
        m.d.sync += count.eq(count + 1)

        # Formal properties
        m.d.comb += Assert(count <= 255)
        m.d.comb += Cover(count == 100)

        return m
```

### Limitation
Less integrated than Hardcaml - requires export step and external tooling.

---

## Formal Verification Resources

- [ZipCPU Formal Verification Tutorial](https://zipcpu.com/tutorial/formal.html) - Excellent free course
- [SymbiYosys Documentation](https://symbiyosys.readthedocs.io/)
- [hardcaml_verify on OPAM](https://ocaml.org/p/hardcaml_verify/)
- [Hardcaml Paper (includes verification)](https://arxiv.org/abs/2312.15035)

---

# Recommendation Matrix

## By Background

| Your Background | Recommended HDL |
|----------------|-----------------|
| Python developer | **Amaranth** |
| Digital design course | **Verilog** |
| Functional programming (Haskell/F#/OCaml) | **Hardcaml** |
| Scala/JVM developer | **Chisel** |
| Want free t-shirt | **Hardcaml** (just 1 puzzle!) |
| No preference, want easiest path | **Amaranth** |
| Want most transferable skills | **Verilog** |

## By Goal

| Your Goal | Recommended HDL |
|-----------|-----------------|
| Learn industry-standard HDL | Verilog |
| Fastest working simulation | Amaranth |
| Free t-shirt with minimal effort | Hardcaml (1 puzzle) |
| Explore functional hardware design | Hardcaml |
| RISC-V ecosystem experience | Chisel |
| **Formal verification priority** | **Hardcaml** ⭐ |
| Formal verification (industry-std) | Verilog + SymbiYosys |

---

# Important Challenge Rules

- **No AI-generated submissions** - must be original work
- **Synthesizable RTL only** - no simulation-only constructs (`$display` ok in testbench, not design)
- **Realistic resource usage** - no infinite parallelism brute force
- **Open source requirement** - your code will be public

---

# Sources
- [Jane Street FPGA Challenge](https://blog.janestreet.com/advent-of-fpga-challenge-2025/)
- [Icarus Verilog](https://steveicarus.github.io/iverilog/)
- [Hardcaml GitHub](https://github.com/janestreet/hardcaml)
- [Amaranth HDL](https://amaranth-lang.org/docs/amaranth/latest/)
- [Chisel](https://www.chisel-lang.org/)
- [Verilog on Apple Silicon](https://k0nze.dev/posts/verilog-apple-silicon/)
