# Project Structure

```
.
├── tool                                 -- the software folder
├── config                               -- the configuration folder
├── raw                                  -- the material
├── log                                  -- the log folder
│   └── 20191026
├── oneshell
│   ├── base.sh                          -- initial script, set env
│   ├── batch_remote_script.sh           -- run cmds at the remote machine
│   ├── batch_sync_files.sh              -- transfer the files between local and remote 
│   ├── blibs                            -- the library of business logic
│   │   └── cpu.sh
│   ├── demo                             -- the demo scripts using the project
│   │   ├── base.sh                      -- same with base.sh in the parent folder 
│   │   ├── batch_network_test.sh
│   │   ├── batch_performance_test.sh
│   │   └── batch_simulate_load.sh
│   ├── libs                             -- the library of project
│   │   ├── crypt.sh                     -- crypt/decrypt the text
│   │   ├── libvirt.sh                   -- control automatically the vms with console 
│   │   ├── linux.sh                     -- the common functions in this project
│   │   ├── log.sh                       -- the log function
│   │   └── ssh.sh                       -- control the remote machine with ssh 
│   ├── LICENSE
│   ├── README.md                        -- document
│   ├── temp.sh                          -- temporary function to test 
│   └── test_local_method.sh             -- testing the function of library in the local
└── result                               -- the result folder
    └── 20191026
```

# log
## local log
all temporary log file will be located in **log** with the same level of oneshell, and separated by date folder

## remote log
all result log will be located in **/tmp/oneshell_$USER**, and separated by date folder

# result


