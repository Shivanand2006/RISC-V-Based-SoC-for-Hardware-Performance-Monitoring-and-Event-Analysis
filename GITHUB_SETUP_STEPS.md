# GitHub Account and Repository Setup Guide

## RISC-V Based SoC for Hardware Performance Monitoring and Event Analysis

---

| Field | Details |
|---|---|
| **Document Type** | GitHub Setup Guide |
| **Student ID** | 1602-23-735-108 |
| **Project Repository** | https://github.com/Shivanand2006/RISC-V-Based-SoC-for-Hardware-Performance-Monitoring-and-Event-Analysis |

---

## 1. Creating a GitHub Account

GitHub is the world's leading platform for version-controlled code collaboration. The following steps walk through creating an account from scratch.

### Step 1 — Navigate to GitHub

Open your browser and go to **https://github.com**. You will see the GitHub homepage with a "Sign up" button in the top-right corner.

> [!NOTE]
> If you already have a GitHub account, skip to Section 3 (Configure Git).

### Step 2 — Click "Sign up"

Clicking "Sign up" takes you to the account creation wizard. GitHub uses a step-by-step flow:

1. **Enter your email address** – Use a permanent email (university email recommended for free GitHub Education benefits).
2. **Create a password** – At least 8 characters, mixing letters, numbers, and symbols.
3. **Choose a username** – This becomes your GitHub handle (e.g., `Shivanand2006`). It appears in all repository URLs. Choose something professional and memorable.
4. **Email preferences** – Choose whether to receive product updates.
5. **Verify your account** – Complete the CAPTCHA puzzle.
6. **Click "Create account"**.

### Step 3 — Verify Your Email

GitHub sends a verification email to the address you provided. Open the email and click **"Verify email address"**. Without this step, you cannot create repositories.

### Step 4 — Complete Setup

After verification, GitHub asks a few optional questions (team size, role, interests). You can skip these by clicking "Skip personalization". You will be taken to your personal dashboard.

### Step 5 — Enable Two-Factor Authentication (Recommended)

Go to **Settings → Password and authentication → Two-factor authentication** and enable it using an authenticator app (Google Authenticator, Authy) for security.

### Step 6 — Apply for GitHub Education (Optional but Recommended)

Students can apply at **https://education.github.com** for free access to:
- **GitHub Pro** (unlimited private repos, advanced Insights)
- **GitHub Copilot** (AI code assistant)
- Free credits for other developer tools

---

## 2. Installing Git

Git is the distributed version control system that powers GitHub. You need Git installed locally to push code from your machine.

### 2.1 Linux (Ubuntu / Debian)

```bash
sudo apt-get update
sudo apt-get install -y git
git --version   # verify: git version 2.x.x
```

### 2.2 Windows

**Option A – Git for Windows (recommended):**

1. Download the installer from **https://git-scm.com/download/win**.
2. Run the `.exe` installer; accept defaults.
3. Ensure "Git Bash" and "Git from the command line" are selected.
4. Open **Git Bash** and verify:

```bash
git --version
```

**Option B – Windows Subsystem for Linux (WSL2):**

```powershell
# In PowerShell (Admin)
wsl --install
# Then inside WSL Ubuntu terminal:
sudo apt-get install -y git
```

### 2.3 macOS

```bash
# Option A: Xcode Command Line Tools (easiest)
xcode-select --install

# Option B: Homebrew
brew install git

git --version   # verify
```

---

## 3. Configuring Git

Before making your first commit, configure Git with your identity. These settings are stored globally in `~/.gitconfig`.

```bash
git config --global user.name  "Shivanand"
git config --global user.email "your_email@example.com"

# Set default branch name to 'main'
git config --global init.defaultBranch main

# Set preferred editor (VS Code example)
git config --global core.editor "code --wait"

# Verify configuration
git config --list
```

### 3.1 SSH Key Setup (Recommended over HTTPS)

SSH keys allow password-free pushes:

```bash
# Generate RSA 4096-bit key
ssh-keygen -t ed25519 -C "your_email@example.com"
# Press Enter to accept default path (~/.ssh/id_ed25519)
# Enter a passphrase (optional but recommended)

# Start SSH agent and add key
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

# Copy public key to clipboard
cat ~/.ssh/id_ed25519.pub
```

Then go to **GitHub → Settings → SSH and GPG keys → New SSH key**, paste the public key, and click "Add SSH key".

Test the connection:

```bash
ssh -T git@github.com
# Expected: Hi Shivanand2006! You've successfully authenticated…
```

---

## 4. Creating a New Repository

### 4.1 Via GitHub Web UI

1. Click the **"+"** icon in the top-right corner of GitHub and select **"New repository"**.
2. Fill in the repository form:

| Field | Value for This Project |
|---|---|
| **Repository name** | `RISC-V-Based-SoC-for-Hardware-Performance-Monitoring-and-Event-Analysis` |
| **Description** | `Synthesizable Verilog-2001 RISC-V SoC with hardware performance monitoring IPs` |
| **Visibility** | Public (for portfolio visibility) or Private |
| **Initialize with README** | ✅ Yes |
| **Add .gitignore** | Select **C** template (we will customise it) |
| **Choose a license** | Apache 2.0 (open-source friendly) |

3. Click **"Create repository"**.

### 4.2 Naming Conventions

| Convention | Example |
|---|---|
| Use hyphens, not spaces | `my-riscv-soc` |
| Lowercase preferred | `risc-v-soc` |
| Descriptive but concise | `veer-el2-hpm-soc` |
| Include technology keyword | `riscv`, `verilog`, `fpga` |

### 4.3 Recommended `.gitignore` for C + Verilog Projects

Create or update `.gitignore` in the repository root:

```gitignore
# Compiled object files
*.o
*.elf
*.bin
*.hex
*.map

# Simulation outputs
*.vcd
*.fsdb
*.vpd
simv
simv.daidir/
csrc/
*.log
*.key

# Synopsys VCS / Verdi temporaries
*.syn
DVEfiles/
verdiLog/
novas.rc
novas.conf

# RISC-V toolchain intermediates
*.d
*.lst
*.dis

# Python
__pycache__/
*.pyc
*.pyo

# Editor files
.vscode/
*.swp
*~
.DS_Store

# Waveform databases (can be large)
*.shm/
```

---

## 5. Cloning the Repository

After creating the repository on GitHub, clone it to your local machine:

```bash
# Using SSH (recommended)
git clone git@github.com:Shivanand2006/RISC-V-Based-SoC-for-Hardware-Performance-Monitoring-and-Event-Analysis.git

# Using HTTPS (if SSH is not configured)
git clone https://github.com/Shivanand2006/RISC-V-Based-SoC-for-Hardware-Performance-Monitoring-and-Event-Analysis.git

# Navigate into the cloned directory
cd RISC-V-Based-SoC-for-Hardware-Performance-Monitoring-and-Event-Analysis
```

---

## 6. Adding Project Files

### 6.1 Standard Workflow

```bash
# 1. Check current status
git status

# 2. Stage specific files
git add rtl/soc_top.v rtl/bus_decoder.v

# 3. Stage an entire directory
git add rtl/

# 4. Stage all changes
git add .

# 5. Review what is staged
git diff --cached --stat

# 6. Commit with a descriptive message
git commit -m "feat(rtl): add initial soc_top and bus_decoder skeleton"

# 7. Push to GitHub
git push origin main
```

### 6.2 Commit Message Conventions

Use the **Conventional Commits** format for a clean, readable history:

```
<type>(<scope>): <short description>

[optional body]
[optional footer]
```

| Type | Usage |
|---|---|
| `feat` | New feature or RTL module |
| `fix` | Bug fix |
| `test` | Testbench additions |
| `docs` | Documentation changes |
| `refactor` | Code restructuring, no behaviour change |
| `sim` | Simulation script changes |
| `sw` | Firmware changes |

**Examples:**

```bash
git commit -m "feat(hpm): implement cycle_cnt_top with shadow register"
git commit -m "test(tb): add self-checking assertions to tb_cycle_cnt"
git commit -m "sw: add perf_app.c CPI measurement loop"
git commit -m "fix(bus): correct byte-enable mask in reg_slave_if"
git commit -m "docs: add memory map table to README"
```

### 6.3 Viewing History

```bash
git log --oneline --graph --all   # compact graphical history
git log --stat                     # history with file change stats
git show HEAD                      # show most recent commit details
```

---

## 7. Repository Structure

Organise the repository into well-defined directories. The recommended layout for this project is:

```
RISC-V-Based-SoC-for-Hardware-Performance-Monitoring-and-Event-Analysis/
│
├── README.md                   # Project overview and quick-start guide
├── .gitignore
├── LICENSE
│
├── rtl/                        # All synthesizable Verilog RTL
│   ├── soc_top.v               # SoC top-level
│   ├── bus_decoder.v           # Address decoder / interconnect
│   ├── reg_slave_if.v          # Register slave interface (shared)
│   ├── veer_core_adapter.sv    # VeeR EL2 AHB adapter
│   ├── cycle_cnt_top.v         # Cycle Counter HPM IP
│   ├── instr_cnt_top.v         # Instruction Counter HPM IP
│   ├── event_cnt_top.v         # Event Counter HPM IP
│   ├── uart_top.v              # UART peripheral
│   ├── timer_top.v             # Timer peripheral
│   ├── gpio_top.v              # GPIO peripheral
│   ├── imem.v                  # Instruction Memory
│   └── dmem.v                  # Data Memory
│
├── tb/                         # Testbenches (not synthesizable)
│   ├── tb_soc_top.v            # SoC-level integration testbench
│   ├── tb_cycle_cnt.v          # Cycle Counter unit testbench
│   ├── tb_instr_cnt.v          # Instruction Counter unit testbench
│   ├── tb_event_cnt.v          # Event Counter unit testbench
│   └── tb_bus_decoder.v        # Bus decoder testbench
│
├── sw/                         # Bare-metal firmware
│   ├── include/
│   │   └── perf_regs.h         # Register address definitions
│   ├── crt0.S                  # Startup code (stack setup, main call)
│   ├── link.ld                 # Linker script
│   ├── Makefile                # Build system
│   ├── test_cycle.c            # Cycle counter unit test
│   ├── test_instr.c            # Instruction counter unit test
│   ├── test_event.c            # Event counter unit test
│   └── perf_app.c              # Integrated perf benchmarking app
│
├── run/                        # Simulation run scripts
│   ├── run_ip.sh               # Run a specific IP testbench
│   ├── run_soc.sh              # Run SoC-level testbench
│   ├── compile_fw.sh           # Compile firmware and generate hex
│   └── Makefile                # Top-level simulation Makefile
│
├── sim_out/                    # Simulation outputs (gitignored binary)
│   ├── *.fsdb                  # Verdi waveform files (not committed)
│   └── *.log                   # Simulation logs
│
└── doc/                        # Documentation
    ├── 01_project_proposal.md
    ├── 02_architecture_spec.md
    ├── 03_github_steps.md
    ├── 04_riscv_toolchain_setup.md
    └── 05_address_map.md
```

### 7.1 Why This Structure?

| Directory | Rationale |
|---|---|
| `rtl/` | Separates synthesizable RTL from simulation-only code |
| `tb/` | All testbenches in one place; never included in synthesis |
| `sw/` | Firmware is a separate domain from hardware; has its own build system |
| `run/` | Scripts are environment-specific; keep separate from functional code |
| `doc/` | Formal documentation tracked alongside the code that implements it |
| `sim_out/` | Generated artifacts; gitignored to avoid bloating the repository |

---

## 8. Branching Strategy

A disciplined branching strategy keeps `main` always in a working, reviewable state.

### 8.1 Branch Naming

```
main          → Always-stable, submission-ready code
dev           → Active development integration branch
feature/<name> → Individual feature branches (merge to dev)
fix/<name>    → Bug fix branches (merge to dev or main)
```

### 8.2 Recommended Flow

```bash
# Start a new feature from dev
git checkout dev
git pull origin dev
git checkout -b feature/cycle-counter-shadow-reg

# ... do work, commits ...

# Push feature branch to GitHub
git push -u origin feature/cycle-counter-shadow-reg

# Create a Pull Request on GitHub: feature/... → dev
# After review (or self-review), merge via GitHub UI

# Periodically merge dev to main when milestones are complete
git checkout main
git merge --no-ff dev
git push origin main
git tag -a v0.1 -m "M2: RTL design complete"
git push origin v0.1
```

### 8.3 Release Tagging

Tag each milestone for easy reference:

```bash
git tag -a v0.1 -m "Milestone 1: Architecture freeze"
git tag -a v0.2 -m "Milestone 2: RTL complete"
git tag -a v0.3 -m "Milestone 3: Unit verification done"
git tag -a v1.0 -m "Final submission"
git push origin --tags
```

---

## 9. GitHub Actions CI (Optional)

A basic GitHub Actions workflow can automatically lint Verilog files on every push or pull request.

### 9.1 Verilog Lint CI with `verilator --lint-only`

Create the file `.github/workflows/lint.yml`:

```yaml
name: Verilog Lint

on:
  push:
    branches: [main, dev]
  pull_request:
    branches: [main, dev]

jobs:
  lint:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Install Verilator
        run: |
          sudo apt-get update
          sudo apt-get install -y verilator

      - name: Lint RTL files
        run: |
          for f in rtl/*.v; do
            echo "Linting: $f"
            verilator --lint-only --Wno-fatal -I./rtl "$f" || true
          done

      - name: Report
        run: echo "Lint complete. Review warnings above."
```

> [!TIP]
> The `|| true` prevents the workflow from failing on warnings during development. Remove it for stricter enforcement before final submission.

### 9.2 Firmware Build Check

Optionally add a firmware compilation check:

```yaml
  firmware-build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install RISC-V toolchain
        run: |
          sudo apt-get update
          sudo apt-get install -y gcc-riscv64-unknown-elf
      - name: Build firmware
        run: |
          cd sw
          make all CROSS=riscv64-unknown-elf-
```

---

## 10. Steps Taken for This Project's GitHub Repository

The following specific steps were taken to set up the project repository at:  
**https://github.com/Shivanand2006/RISC-V-Based-SoC-for-Hardware-Performance-Monitoring-and-Event-Analysis**

### Step 1 — Account Creation

A GitHub account was created under the username **Shivanand2006** with university email verification completed.

### Step 2 — Repository Initialisation

The repository was created via the GitHub web UI with:
- The full descriptive name matching the project title
- An initialised `README.md`
- A `C` `.gitignore` template (later extended with Verilog/EDA entries)
- Apache 2.0 license

### Step 3 — Local Clone

```bash
git clone git@github.com:Shivanand2006/RISC-V-Based-SoC-for-Hardware-Performance-Monitoring-and-Event-Analysis.git
cd RISC-V-Based-SoC-for-Hardware-Performance-Monitoring-and-Event-Analysis
```

### Step 4 — Directory Structure Creation

```bash
mkdir -p rtl tb sw/include run sim_out doc
touch rtl/.gitkeep tb/.gitkeep sw/.gitkeep run/.gitkeep doc/.gitkeep
git add .
git commit -m "chore: initialize repository directory structure"
git push origin main
```

### Step 5 — RTL Files Added Incrementally

Each HPM IP was developed and committed separately:

```bash
# After implementing cycle counter
git add rtl/reg_slave_if.v rtl/cycle_cnt_top.v
git commit -m "feat(hpm): add cycle_cnt_top with 64-bit shadow register"
git push

# After implementing instruction counter
git add rtl/instr_cnt_top.v
git commit -m "feat(hpm): add instr_cnt_top tracking trace_rv_i_valid_ip"
git push

# After implementing event counter
git add rtl/event_cnt_top.v
git commit -m "feat(hpm): add event_cnt_top with threshold interrupt and W1C status"
git push
```

### Step 6 — Testbenches and Firmware Added

```bash
git add tb/ sw/
git commit -m "test: add unit testbenches for all HPM IPs"
git commit -m "sw: add perf_regs.h, crt0.S, link.ld, and all test programs"
git push
```

### Step 7 — SoC Integration

```bash
git add rtl/soc_top.v rtl/bus_decoder.v rtl/veer_core_adapter.sv
git add rtl/uart_top.v rtl/timer_top.v rtl/gpio_top.v
git add rtl/imem.v rtl/dmem.v
git add tb/tb_soc_top.v
git commit -m "feat(soc): integrate all IPs into soc_top with bus_decoder"
git push
```

### Step 8 — Documentation Committed

```bash
git add doc/
git commit -m "docs: add architecture spec, address map, and setup guides"
git push
```

### Step 9 — README Updated

The `README.md` was updated with:
- Project overview and block diagram (ASCII art)
- Quick-start simulation instructions
- Memory map table
- Toolchain requirements
- File listing

### Step 10 — Final Tag

```bash
git tag -a v1.0 -m "Final submission: all RTL, testbenches, firmware, and documentation"
git push origin v1.0
```

---

*End of GitHub Setup Guide*
