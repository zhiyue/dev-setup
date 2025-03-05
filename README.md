## 仓库结构

```
dev-environment/
├── README.md
├── common/                # 跨平台共享脚本
│   ├── git-config.sh      
│   └── vscode-extensions.sh
├── mac/                   # Mac特定脚本
│   ├── install.sh         # Mac主安装脚本
│   ├── brew-essentials.sh
│   └── macos-defaults.sh
└── windows/               # Windows特定脚本
    ├── install.ps1        # Windows主安装脚本
    ├── chocolatey-setup.ps1
    └── windows-features.ps1
```
