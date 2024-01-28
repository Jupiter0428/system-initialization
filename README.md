# system-initialization

This script performs initialization operations on newly deployed Linux servers, covering some basic function adjustments and performance adjustments.

## Compatibility

- CentOS 7 and later
- Ubuntu 20 and later

## Optional Features

- **root-check** Confirm whether the script is currently executed as the root user.
- **system-check** Get Linux distribution.
- **system-optimize** To make simple adjustments and optimizations to system tcp, etc, parameters need to be adjusted for different hardware configurations.
- **system-update** Upgrade the system to the latest LT version.
- **system-firewall** Turn off the firewall that is enabled by default.
- **resource-limits** Adjust the resource limit limit.
- **tcp-bbr** Enable BBR TCP congestion algorithm.
- **script-update** Update the script to the latest.
- **ssh-port** Adjust ssh listening port.
- **ssh-key** Establish ssh key connection.

## Usage

Just download and execute the script:

```sh
wget https://raw.githubusercontent.com/Jupiter0428/system-initialization/master/initial.sh
chmod +x ./initial.sh
./initial.sh $1 $2
```