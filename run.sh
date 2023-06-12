#!/bin/bash
# First check that Leo is installed.
if ! command -v leo &> /dev/null
then
    echo "leo is not installed."
    exit
fi

echo "
###############################################################################
########                                                               ########
########               STEP 0: Compile the vote program                ########
########                                                               ########
###############################################################################
"
# Build the Leo vote program.
(
  leo build || exit
)

# 1: Initializing Player 1
echo "
###############################################################################
########                                                               ########
########                 STEP 1: Initializing Player 1                 ########
########                                                               ########
###############################################################################
"
echo "{
  \"program\": \"aleo_bingo.aleo\",
  \"version\": \"0.0.0\",
  \"description\": \"\",
  \"development\": {
      \"private_key\": \"APrivateKey1zkpGKaJY47BXb6knSqmT3JZnBUEGBDFAWz2nMVSsjwYpJmm\",
      \"view_key\": \"AViewKey1fSyEPXxfPFVgjL6qcM9izWRGrhSHKXyN3c64BNsAjnA6\",
      \"address\": \"aleo15g9c69urtdhvfml0vjl8px07txmxsy454urhgzk57szmcuttpqgq5cvcdy\"
  },
  \"license\": \"MIT\"
}" > program.json

echo "✅ Successfully initialized Player 1."


# 2: Player 1 Starts Bingo Game
echo "
###############################################################################
########                                                               ########
########               STEP 2: Player 1 Starts Bingo Game              ########
########                                                               ########
###############################################################################
"
leo run create_game 1u64 1u64 1000000u64 21888242871839275222246405745257275088548364400416034343698204186575808495617field