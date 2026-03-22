## Standalone reference constraints for the optional demo wrapper.
## This is NOT the handout's hidden USB-UART wrapper; it is only a self-contained fallback.
## It drives UART TX/RX on PL pins so you can use an external CH340/USB-UART dongle.
## BTN0 is reserved for reset.

set_property -dict { PACKAGE_PIN H16 IOSTANDARD LVCMOS33 } [get_ports { clk_125mhz }]
create_clock -name clk_125mhz -period 8.000 [get_ports { clk_125mhz }]

## PMODB pin 1 -> UART TX to external dongle RXD
set_property -dict { PACKAGE_PIN W19 IOSTANDARD LVCMOS33 } [get_ports { uart_txd }]

## PMODB pin 2 -> UART RX from external dongle TXD
set_property -dict { PACKAGE_PIN W18 IOSTANDARD LVCMOS33 } [get_ports { uart_rxd }]