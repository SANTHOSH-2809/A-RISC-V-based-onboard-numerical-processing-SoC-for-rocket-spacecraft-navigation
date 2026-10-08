# A-RISC-V-based-onboard-numerical-processing-SoC-for-rocket-spacecraft-navigation

Why I like this project
There is a real engineering motivation behind onboard numerical processing.
NASA describes onboard computing as responsible for real-time control, command execution, telemetry generation, data storage and subsystem coordination. NASA
And RISC-V + FPGA onboard computing is not a random academic combination. Research has explored RISC-V soft processors for spaceflight, including FPGA implementations and fault-injection testing. Southwest Research Institute
There is also very recent work showing that spacecraft workloads can benefit significantly from domain-specific accelerators. A 2026 study reported that trigonometric functions and small matrix operations are major computational bottlenecks in spacecraft workloads, and demonstrated RISC-V-connected CORDIC and matrix accelerators. EurekaMag
That gives you a very good justification for your architecture.
