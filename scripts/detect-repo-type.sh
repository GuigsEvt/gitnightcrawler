#!/bin/bash
# Detect the type of a repository to determine which Trail of Bits skills to apply
# Returns a pipe-separated list of categories: blockchain|ai|web|crypto|mobile|general
# Usage: ./detect-repo-type.sh <repo_dir>

set -euo pipefail

REPO_DIR="${1:-.}"

if [ ! -d "$REPO_DIR" ]; then
    echo "general"
    exit 0
fi

cd "$REPO_DIR"

CATEGORIES=""

# Collect all file names and content indicators
FILES=$(find . -maxdepth 4 -type f \( -name "*.sol" -o -name "*.vy" -o -name "*.cairo" -o -name "*.move" \
    -o -name "*.teal" -o -name "*.pyteal" -o -name "*.func" -o -name "*.fc" \
    -o -name "*.rs" -o -name "*.go" -o -name "*.py" -o -name "*.ts" -o -name "*.js" \
    -o -name "*.tsx" -o -name "*.jsx" -o -name "Cargo.toml" -o -name "package.json" \
    -o -name "go.mod" -o -name "requirements.txt" -o -name "Pipfile" \
    -o -name "Anchor.toml" -o -name "hardhat.config.*" -o -name "foundry.toml" \
    -o -name "truffle-config.*" -o -name "brownie-config.yaml" \
    -o -name "*.apk" -o -name "AndroidManifest.xml" -o -name "*.swift" -o -name "*.kt" \
    \) 2>/dev/null | head -500)

# --- Blockchain detection ---
# Solidity / EVM
if echo "$FILES" | grep -qE '\.(sol|vy)$' || \
   [ -f "hardhat.config.js" ] || [ -f "hardhat.config.ts" ] || \
   [ -f "foundry.toml" ] || [ -f "truffle-config.js" ] || \
   [ -f "brownie-config.yaml" ]; then
    CATEGORIES="${CATEGORIES}ethereum|"
fi

# Solana
if [ -f "Anchor.toml" ] || echo "$FILES" | grep -qE 'programs/.*\.rs$' || \
   grep -rql "solana_program\|anchor_lang\|@solana/web3" . --include="*.rs" --include="*.ts" --include="*.json" 2>/dev/null | head -1 > /dev/null; then
    CATEGORIES="${CATEGORIES}solana|"
fi

# Cairo / StarkNet
if echo "$FILES" | grep -qE '\.cairo$' || \
   grep -rql "starknet\|cairo" . --include="*.toml" --include="*.json" 2>/dev/null | head -1 > /dev/null; then
    CATEGORIES="${CATEGORIES}cairo|"
fi

# Algorand / TEAL
if echo "$FILES" | grep -qE '\.(teal|pyteal)$' || \
   grep -rql "algosdk\|pyteal\|algorand" . --include="*.py" --include="*.ts" --include="*.json" 2>/dev/null | head -1 > /dev/null; then
    CATEGORIES="${CATEGORIES}algorand|"
fi

# Cosmos
if grep -rql "cosmos-sdk\|cosmwasm\|tendermint" . --include="*.go" --include="*.toml" --include="*.json" 2>/dev/null | head -1 > /dev/null; then
    CATEGORIES="${CATEGORIES}cosmos|"
fi

# Substrate / Polkadot
if grep -rql "substrate\|frame_support\|polkadot" . --include="*.rs" --include="*.toml" --include="*.json" 2>/dev/null | head -1 > /dev/null; then
    CATEGORIES="${CATEGORIES}substrate|"
fi

# TON / FunC
if echo "$FILES" | grep -qE '\.(func|fc)$' || \
   grep -rql "ton-core\|tonweb\|@ton" . --include="*.ts" --include="*.json" 2>/dev/null | head -1 > /dev/null; then
    CATEGORIES="${CATEGORIES}ton|"
fi

# Generic blockchain/web3/DeFi (only code imports, not docs)
if echo "$CATEGORIES" | grep -qE '(ethereum|solana|cairo|algorand|cosmos|substrate|ton)'; then
    CATEGORIES="${CATEGORIES}blockchain|"
elif grep -rqwl "web3\|ethers\|DeFi\|smart_contract\|erc20\|erc721\|hardhat\|foundry" . --include="*.ts" --include="*.js" --include="*.py" 2>/dev/null; then
    CATEGORIES="${CATEGORIES}blockchain|"
fi

# --- AI / ML detection ---
if grep -rql "torch\|tensorflow\|transformers\|langchain\|llama_index\|openai\|anthropic\|ollama\|vllm\|huggingface\|sklearn\|keras\|paddlepaddle\|onnx\|model_context_protocol\|mcp" \
   . --include="*.py" --include="*.ts" --include="*.js" --include="*.toml" --include="*.json" 2>/dev/null | head -3 > /dev/null; then
    CATEGORIES="${CATEGORIES}ai|"
fi

# --- GitHub Actions / CI detection ---
if [ -d ".github/actions" ] || [ -d ".github/workflows" ]; then
    CATEGORIES="${CATEGORIES}actions|"
fi

# --- Mobile detection ---
if echo "$FILES" | grep -qE '\.(apk|swift|kt)$' || [ -f "AndroidManifest.xml" ] || \
   grep -rql "firebase\|google-services" . --include="*.json" --include="*.gradle" 2>/dev/null | head -1 > /dev/null; then
    CATEGORIES="${CATEGORIES}mobile|"
fi

# --- Crypto / C/C++/Rust low-level detection ---
if grep -rql "openssl\|libsodium\|ring::\|rustcrypto\|constant_time\|hmac\|aes\|chacha\|ed25519\|x25519\|sha256\|sha512\|pbkdf2\|argon2\|scrypt" \
   . --include="*.rs" --include="*.c" --include="*.h" --include="*.cpp" --include="*.go" 2>/dev/null | head -3 > /dev/null; then
    CATEGORIES="${CATEGORIES}crypto-primitives|"
fi

# Default fallback
if [ -z "$CATEGORIES" ]; then
    CATEGORIES="general|"
fi

# Remove trailing pipe and output
echo "${CATEGORIES%|}"
