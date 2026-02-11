# Auth Controller

- [Interfaces](#Interfaces)
    - [generate_challenge](#generate_challenge)
    - [verify_id](#verify_id)

## Interfaces

### generate_challenge

This module reads the encrypted `AUTH_INIT`, decrypts it, then generates
a challenge response and sends it to the card.

For data transmissions, a ready(valid handshake system is used.
This essentially means that the producer waits for both the
`valid` and `ready` flags to be send and then writes the next
set of output bytes to the corresponding bus.

The received rc and rt values are stored in 64 bit registers (flipflops)
until they are consumed by `verify_id` or overwritten.

Inputs:

| Name & Type | Comment |
|-------------|---------|
| `input logic clk` | Clock |
| `input logic rst` | Reset |
| `input logic external_ready` | Ready/Valid handshake component. |
| `input logic external_valid` | Ready/Valid handshake component. |
| `input logic [7:0] input_cipher` | The data send by the cards `AUTH_INIT`, send byte by byte. |

Outputs:

| Name & Type | Comment |
|-------------|---------|
| `output logic error` | Flag to indicate authentication failure. |
| `output logic invalid_valid` | Ready/Valid handshake component. |
| `output logic invalid_ready` | Ready/Valid handshake component. |
| `output logic [7:0] challenge_response` | The generated challenge, send byte by byte. |

---

### verify_id

This module receives an ID encrypted with a session key, decrypts it and
verifies that it is allowed to access the lock. The values rc and rt needed
for calculating the session key are read from two 64 bit registers.

Inputs:

| Name & Type | Comment |
|-------------|---------|
| `input logic clk` | Clock |
| `input logic rst` | Reset |
| `input logic external_valid` | Ready/Valid handshake component. |
| `input logic [7:0] id_cipher` | The encrypted ID of the cardy, send byte by byte. |

Outputs:

| Name & Type | Comment |
|-------------|---------|
| `output logic error` | Flag to indicate authentication failure. |
| `output logic success` | Flag to indicate authentication success. |
| `output logic internal_ready` | Ready/Valid handshake component. |

