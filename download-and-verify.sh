#!/bin/bash

# Script Constants
BASE_URL="https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/"
ISO_NAME="debian-12.2.0-amd64-netinst.iso"
SHA256_CHECKSUM_FILE="SHA256SUMS"
SHA512_CHECKSUM_FILE="SHA512SUMS"
SHA256_SIGNATURE_FILE="${SHA256_CHECKSUM_FILE}.sign"
SHA512_SIGNATURE_FILE="${SHA512_CHECKSUM_FILE}.sign"
DEBIAN_KEYSERVER="keyring.debian.org"
PATH_OUT="./output"

# Define the files and their corresponding URLs
declare -A FILE_URLS=(
  ["$ISO_NAME"]="${BASE_URL}${ISO_NAME}"
  ["$SHA256_CHECKSUM_FILE"]="${BASE_URL}${SHA256_CHECKSUM_FILE}"
  ["$SHA512_CHECKSUM_FILE"]="${BASE_URL}${SHA512_CHECKSUM_FILE}"
  ["$SHA256_SIGNATURE_FILE"]="${BASE_URL}${SHA256_SIGNATURE_FILE}"
  ["$SHA512_SIGNATURE_FILE"]="${BASE_URL}${SHA512_SIGNATURE_FILE}"
)

# Function Definitions

create_output_dir() {
  mkdir -p "$PATH_OUT" && cd "$PATH_OUT" || exit 1
}

download_file() {
  local file=$1
  local url=$2
  if [ ! -f "$file" ]; then
    echo "Downloading $file..."
    curl -L -o "$file" "$url" || { echo "Failed to download $file"; exit 1; }
  else
    echo "$file already downloaded. Skipping download."
  fi
}

download_files() {
  for file in "${!FILE_URLS[@]}"; do
    download_file "$file" "${FILE_URLS[$file]}"
  done
}

extract_key_id() {
  local signature_file=$1
  gpg --list-packets "$signature_file" | grep -Po '(?<=keyid ).*' | head -1
}

import_gpg_keys() {
  local key_id
  key_id=$(extract_key_id "$SHA256_SIGNATURE_FILE")
  echo "Receiving key $key_id from Debian keyserver..."
  gpg --keyserver "$DEBIAN_KEYSERVER" --recv-keys "$key_id" || { echo "Failed to receive GPG key $key_id"; exit 1; }
}

verify_checksum() {
  local checksum_file=$1
  local checksum_type=$2
  echo "Verifying the checksum of the ISO using $checksum_file..."
  grep "$ISO_NAME" "$checksum_file" | $checksum_type -c || { echo "Checksum verification using $checksum_file failed!"; exit 1; }
  echo "Checksum verified successfully using $checksum_file."
}

verify_gpg_signature() {
  local signature_file=$1
  local checksum_file=${signature_file%.*}
  echo "Verifying the GPG signature of $checksum_file..."
  gpg --verify "$signature_file" "$checksum_file" || { echo "GPG signature verification for $checksum_file failed!"; exit 1; }
  echo "GPG signature verified successfully for $checksum_file."
}

main() {
  create_output_dir
  download_files
  import_gpg_keys
  verify_gpg_signature "$SHA256_SIGNATURE_FILE"
  verify_gpg_signature "$SHA512_SIGNATURE_FILE"
  verify_checksum "$SHA256_CHECKSUM_FILE" "sha256sum"
  verify_checksum "$SHA512_CHECKSUM_FILE" "sha512sum"
  echo "Download and verification of Debian ISO completed successfully."
}

# Execute the script
main

