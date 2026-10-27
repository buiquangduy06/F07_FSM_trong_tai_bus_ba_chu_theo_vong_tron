# Mach TUAN TU: dinh nghia clock that tu cong clock cua thiet ke.
# Chu ky 10 ns va IO delay 1 ns la GIA DINH phan tich khoi diem,
# KHONG phai yeu cau he thong. Phai neu kem moi con so bao cao.
create_clock -name clk -period 10.0 [get_ports clk]
set_input_delay  1.0 -clock clk [get_ports {done req rst_n}]
set_output_delay 1.0 -clock clk [all_outputs]
