# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

# Generates random text for boot diagnostics storage account name
resource "random_id" "post_fix" {
  byte_length = 4
}
