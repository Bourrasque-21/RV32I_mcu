# RISC-V RV32I MCU

## Overview

SystemVerilog로 구현한 멀티사이클 RV32I CPU 기반 FPGA MCU 설계임. CPU 코어, 명령어 ROM, 4 KB(4096 bytes) 데이터 RAM, APB 버스 및 GPIO, UART, FND 주변장치를 하나의 SoC 형태로 구성함.

Digilent Basys 3 보드를 대상으로 하며, 100 MHz 시스템 클럭과 온보드 스위치, LED, 7-Segment Display 및 USB-UART 인터페이스를 사용함.

## Specifications

- 32비트 RV32I 멀티사이클 CPU
- `IF -> ID -> EX -> MEM -> WB` 상태 기반 제어
- 32개 범용 레지스터와 `x0` 하드와이어드 제로
- 64-word 명령어 ROM
- 4 KB(4096 bytes) 데이터 BRAM
- APB 기반 메모리 맵 주변장치
- 8비트 GPO 및 8비트 GPI
- 16비트 양방향 GPIO
- 4자리 7-Segment Display 제어기
- UART 송수신 및 RX 인터럽트
- Basys 3 보드용 XDC 제약 파일

## System Architecture

![RV32I MCU Block Diagram](docs/images/rv32i_mcu_block_diagram.png)

`rv32i_mcu` TOP 모듈에서 명령어 메모리, RV32I CPU, Bus Router, 데이터 RAM, APB Master 및 APB 주변장치를 통합함. 명령어 메모리는 CPU와 직접 연결되며, CPU의 데이터 접근은 Bus Router에서 RAM 경로와 APB 주변장치 경로로 분기됨.

## CPU Architecture

CPU는 제어부(`control_unit`)와 데이터패스(`datapath`)로 구성됨.

| 상태 | 동작 |
| --- | --- |
| `IF` | 명령어 인출, PC 및 이전 PC 저장 |
| `ID` | 레지스터 피연산자와 즉시값 저장 |
| `EX` | ALU 연산, 분기 및 유효 주소 계산 |
| `MEM` | 데이터 메모리 또는 APB 접근 |
| `WB` | 연산/로드 결과를 레지스터에 기록 |
| `INT` | UART 인터럽트 처리 및 벡터 주소로 이동 |

### Supported Instructions

| 분류 | 명령어 |
| --- | --- |
| Register-Register | `ADD`, `SUB`, `SLL`, `SLT`, `SLTU`, `XOR`, `SRL`, `SRA`, `OR`, `AND` |
| Register-Immediate | `ADDI`, `SLTI`, `SLTIU`, `XORI`, `ORI`, `ANDI`, `SLLI`, `SRLI`, `SRAI` |
| Load | `LB`, `LH`, `LW`, `LBU`, `LHU` |
| Store | `SB`, `SH`, `SW` |
| Branch | `BEQ`, `BNE`, `BLT`, `BGE`, `BLTU`, `BGEU` |
| Jump | `JAL`, `JALR` |
| Upper Immediate | `LUI`, `AUIPC` |

## Memory Map

| 주소 영역 | 크기/간격 | 장치 |
| --- | --- | --- |
| `0x0000_0000` | 256 B | 명령어 ROM |
| `0x1000_0000` | 4 KB (4096 B) | 데이터 BRAM |
| `0x2000_0000` | `0x1000` 간격 | GPO |
| `0x2000_1000` | `0x1000` 간격 | GPI |
| `0x2000_2000` | `0x1000` 간격 | GPIO |
| `0x2000_3000` | `0x1000` 간격 | FND |
| `0x2000_4000` | `0x1000` 간격 | UART |

데이터 RAM은 `addr[11:2]`를 32비트 word 인덱스로 사용함. 하위 2비트 `addr[1:0]`은 byte와 halfword 위치를 선택하는 데 사용되며, 데이터 RAM 주소 범위는 `0x1000_0000`부터 `0x1000_0FFF`까지임.

### RAM Access Architecture

데이터 RAM은 APB Slave로 연결되지 않으며, CPU 데이터 버스와 `bus_router`를 통해 직접 연결됨.

#### RAM Control Flow

1. CPU가 load 또는 store 명령어를 실행하면 `bus_addr`, `bus_wdata`, `bus_rreq`, `bus_wreq`를 출력함.
2. `bus_router`에서 `bus_addr[31:28] == 4'h1` 조건을 검사함.
3. 조건이 참이면 CPU 요청을 `ram_rreq` 또는 `ram_wreq`로 변환하여 `data_dmem`에 전달함.
4. `data_dmem`에서 `funct3` 값에 따라 byte, halfword, word 단위의 읽기 및 쓰기를 처리함.
5. BRAM은 `addr[11:2]`를 이용하여 1024개의 32비트 word 중 하나를 선택함.
6. `ram_rdata`와 `ram_ready`가 `bus_router`를 통해 CPU의 `bus_rdata`와 `bus_ready`로 반환됨.

| CPU 명령어 | `funct3` | RAM 처리 |
| --- | --- | --- |
| `LB`, `LBU` | `000`, `100` | `addr[1:0]`으로 byte 선택 |
| `LH`, `LHU` | `001`, `101` | `addr[1]`로 halfword 선택 |
| `LW` | `010` | 32비트 word 읽기 |
| `SB` | `000` | 선택된 8비트 영역 쓰기 |
| `SH` | `001` | 선택된 16비트 영역 쓰기 |
| `SW` | `010` | 32비트 word 쓰기 |

`data_dmem`의 `ready`는 `mem_read | mem_write`로 생성됨. RAM 요청이 활성화된 경우 해당 접근의 완료 신호가 즉시 CPU 버스 경로로 반환됨.

#### Direct RAM Connection Rationale

APB는 `SETUP`과 `ACCESS` 단계로 구성된 저속 주변장치용 레지스터 버스임. 본 설계에서는 GPO, GPI, GPIO, FND, UART와 같이 소수의 제어 및 상태 레지스터를 갖는 주변장치를 APB에 연결함.

데이터 RAM은 CPU의 load/store 명령어에 의해 반복적으로 접근되는 저장공간이므로 APB 변환 단계를 거치지 않고 직접 연결함. 해당 구조는 다음 특성을 가짐.

- APB의 `SETUP` 및 `ACCESS` 상태를 거치지 않고 RAM 요청을 직접 전달함
- CPU의 `funct3`를 이용한 byte, halfword, word 접근을 RAM 인터페이스에서 직접 처리함
- RAM 데이터 및 완료 신호를 `bus_router`에서 CPU로 직접 반환함
- 메모리 경로와 주변장치 경로를 분리하여 각 인터페이스의 역할을 명확하게 구성함

주소가 RAM 영역이 아닌 경우 `bus_router`에서 요청을 APB Master로 전달함. APB Master는 `0x2000_xxxx` 영역을 디코딩하여 각 주변장치의 `PSEL`을 생성함.

### GPO Registers

기준 주소: `0x2000_0000`

| Offset | 이름 | 접근 | 설명 |
| --- | --- | --- | --- |
| `0x000` | `GPO_CTL` | R/W | 비트가 1인 출력만 활성화 |
| `0x004` | `GPO_ODATA` | R/W | 8비트 LED 출력 데이터 |

### GPI Registers

기준 주소: `0x2000_1000`

| Offset | 이름 | 접근 | 설명 |
| --- | --- | --- | --- |
| `0x000` | `GPI_CTL` | R/W | 비트가 1인 입력만 읽기 활성화 |
| `0x004` | `GPI_IDATA` | R | 8비트 스위치 입력 데이터 |

### GPIO Registers

기준 주소: `0x2000_2000`

| Offset | 이름 | 접근 | 설명 |
| --- | --- | --- | --- |
| `0x000` | `GPIO_CTL` | R/W | 방향 설정: `1=output`, `0=input` |
| `0x004` | `GPIO_ODATA` | R/W | 16비트 출력 데이터 |
| `0x008` | `GPIO_IDATA` | R | 16비트 입력 데이터 |

### FND Registers

기준 주소: `0x2000_3000`

| Offset | 이름 | 접근 | 설명 |
| --- | --- | --- | --- |
| `0x000` | `FND_CTL` | R/W | 16비트 FND 설정 레지스터 |
| `0x004` | `FND_ODATA` | R/W | 표시할 16비트 hexadecimal 값 |

`FND_ODATA`를 4비트 단위의 네 영역으로 분할하며, 각 4비트 값을 한 자리의 16진수 숫자로 표시함.

### UART Registers

기준 주소: `0x2000_4000`

| Offset | 이름 | 접근 | 설명 |
| --- | --- | --- | --- |
| `0x000` | `UART_BAUD` | R/W | Baud rate 선택 (`[1:0]`) |
| `0x004` | `UART_STATUS` | R | `[31]=RX valid`, `[0]=TX busy` |
| `0x008` | `UART_TXDATA` | R/W | 송신 데이터 (`[7:0]`) |
| `0x00C` | `UART_RXDATA` | R | 수신 데이터 (`[7:0]`) |

#### UART Baud Configuration

| `UART_BAUD[1:0]` | Baud rate |
| --- | --- |
| `2'b00` | 9,600 bps |
| `2'b01` | 19,200 bps |
| `2'b10` | 115,200 bps |
| `2'b11` | 9,600 bps |

UART는 100 MHz 입력 클럭을 기준으로 16배 oversampling 방식을 사용함. 프레임 형식은 8 data bits, no parity, 1 stop bit(8N1)로 구성됨.

## Interrupt Architecture

인터럽트는 UART RX 수신 완료 신호를 기반으로 동작함. UART 수신 데이터는 `rx_data_reg`에 저장되며, 수신 데이터가 유효한 동안 `rx_valid_reg`가 인터럽트 pending 플래그 역할을 수행함.

### 1. UART Reception and Interrupt Request

1. `uart_rx` 모듈에서 start bit, 8-bit data, stop bit를 순서대로 수신함.
2. 한 바이트의 수신이 완료되면 `w_rx_done`을 1로 설정함.
3. APB UART에서 수신 데이터를 `rx_data_reg`에 저장하고 `rx_valid_reg`를 1로 설정함.
4. `interrupt_signal`은 `rx_valid_reg`에 직접 연결되어 CPU로 전달됨.
5. 동일한 RX valid 상태를 `UART_STATUS[31]`을 통해 확인할 수 있음.

### 2. CPU Interrupt Entry

CPU 제어기는 `IF` 상태에서 `interrupt_signal`을 확인함. 명령어 실행 도중 인터럽트가 발생한 경우, 실행 중인 명령어의 상태 처리를 완료한 후 다음 `IF` 상태에서 인터럽트를 수락함.

인터럽트 감지 시 제어기가 `INT` 상태로 전이함. `INT` 상태에서 다음 제어 신호가 활성화됨.

| 제어 신호 | 동작 |
| --- | --- |
| `save_return_addr` | 복귀 주소 저장 |
| `pc_en` | PC 갱신 허용 |
| `pc_sel_int` | 인터럽트 벡터 선택 |
| `interrupt_clear` | UART RX valid 해제 요청 |

### 3. Return Address and Interrupt Vector

`save_return_addr` 활성화 시 데이터패스에서 현재 `instr_addr`를 범용 레지스터 `x26`에 저장함. 해당 값은 인터럽트 처리 완료 후 기존 프로그램으로 복귀하기 위한 주소로 사용됨.

동시에 PC 입력을 인터럽트 벡터 상수인 `0x0000_0040`으로 선택함. 명령어 ROM은 word 단위로 접근하므로 해당 벡터 주소는 ROM의 16번째 인덱스에 해당함.

| 항목 | 값 |
| --- | --- |
| 인터럽트 소스 | UART RX data valid |
| 인터럽트 감지 상태 | CPU `IF` 상태 |
| 인터럽트 벡터 | `0x0000_0040` |
| 복귀 주소 레지스터 | `x26` |
| pending 상태 | `UART_STATUS[31]` |

### 4. Interrupt Clear

CPU가 `INT` 상태에 진입하면 `interrupt_clear`가 활성화되어 `rx_valid_reg`가 해제됨. CPU의 인터럽트 진입 전에 소프트웨어에서 `UART_RXDATA` 레지스터를 읽는 경우에도 RX valid가 해제됨.

수신 완료와 clear가 동일한 클럭에 발생하는 경우 신규 수신 완료 처리가 우선되며, 수신 데이터와 RX valid 상태가 유지됨.

### 5. Program Return

인터럽트 서비스 루틴은 `0x0000_0040`부터 실행됨. UART 수신 데이터는 `UART_RXDATA`에서 읽으며, 서비스 처리 완료 후 `x26`에 저장된 주소를 PC에 전달하여 인터럽트 발생 이전의 실행 위치로 복귀함.

## Register Initialization

메모리 맵 접근을 위해 일부 범용 레지스터를 다음 값으로 초기화함.

| 레지스터 | 초기값 | 용도 |
| --- | --- | --- |
| `x27` | `0x1000_0000` | 데이터 RAM base |
| `x28` | `0x2000_4000` | UART baud register |
| `x29` | `0x2000_4004` | UART status register |
| `x30` | `0x2000_4008` | UART TX data register |
| `x31` | `0x2000_400C` | UART RX data register |

## Basys 3 Pin Mapping

| FPGA 포트 | Basys 3 장치 |
| --- | --- |
| `clk` | 100 MHz oscillator |
| `rst` | Center push button |
| `sw[7:0]` | 상위 8개 슬라이드 스위치 |
| `led[7:0]` | 상위 8개 LED |
| `GPIO[7:0]` | 하위 8개 슬라이드 스위치 |
| `GPIO[15:8]` | 하위 8개 LED |
| `fnd_digit[3:0]` | 7-Segment digit enable |
| `fnd_data[7:0]` | 7-Segment segments and decimal point |
| `uart_rx`, `uart_tx` | USB-UART interface |

## Directory Structure

```text
RV32I_mcu/
├── constrs_1/
│   └── imports/FPGA_1/
│       └── Basys-3-Master.xdc
└── sources_1/
    ├── imports/new/
    │   ├── _define.vh
    │   ├── rv32I_top.sv
    │   ├── rv32i_cpu.sv
    │   ├── datapath.sv
    │   ├── instruction_mem.sv
    │   └── data_memory.sv
    └── new/
        ├── _riscv_rv32i_rom_data.mem
        ├── abp_master.sv
        ├── apb_uart.sv
        ├── apb_fnd.sv
        ├── gpo_01.sv
        ├── gpi_02.sv
        ├── gpio_03.sv
        ├── bram.sv
        ├── uart_top.sv
        └── fifo.sv
```

## Program ROM

`instruction_mem`에서 다음 파일을 `$readmemh`로 읽어 프로그램을 초기화함.

```text
sources_1/new/_riscv_rv32i_rom_data.mem
```

메모리 초기화 파일은 한 줄에 하나의 32비트 명령어를 hexadecimal 형식으로 기록함.

```text
10001137
fe010113
00112e23
```

ROM 깊이는 64 word이며, 최대 256 byte의 프로그램을 저장할 수 있음. 프로그램 변경 사항은 synthesis 및 bitstream 생성 과정에서 명령어 ROM에 반영됨.

## Development Environment

- HDL: SystemVerilog
- FPGA board: Digilent Basys 3
- FPGA: Xilinx Artix-7 XC7A35T
- Tool: AMD/Xilinx Vivado
