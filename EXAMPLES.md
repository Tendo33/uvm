# uvm 使用示例

本文档提供 uvm 常见使用场景的实际示例。

## 目录

- [基本工作流](#基本工作流)
- [项目专属环境](#项目专属环境)
- [多 Python 版本](#多-python-版本)
- [共享环境](#共享环境)
- [从 Conda 迁移](#从-conda-迁移)

---

## 基本工作流

### 创建第一个环境

```bash
# 使用默认 Python 版本创建环境
uvm create myenv

# 使用指定 Python 版本创建
uvm create data-science --python 3.11
```

### 安装包

```bash
# 激活环境
uvm activate data-science

# 使用 pip 安装包（UV 加速）
pip install numpy pandas matplotlib scikit-learn

# 或直接使用 uv，更快
uv pip install numpy pandas matplotlib scikit-learn

# 验证安装
python -c "import pandas; print(pandas.__version__)"
```

### 列出和管理环境

```bash
# 列出所有环境
uvm list

# 输出示例：
#   data-science              Python 3.11.5      /home/user/uv_envs/data-science
# * myenv                     Python 3.12.0      /home/user/uv_envs/myenv

# 删除环境
uvm delete myenv
```

---

## 项目专属环境

### 场景 1：使用 pyproject.toml 的现代项目

```bash
# 进入项目目录
cd ~/projects/my-fastapi-app

# 创建本地 .venv
uv venv

# 安装依赖
uv pip install -r requirements.txt
# 或
uv sync  # 如果使用 pyproject.toml

# cd 进入目录时环境自动激活
cd ~/projects/my-fastapi-app
# 🔄 Auto-activating local .venv

# 运行应用
python main.py

# 离开目录
cd ~
# 🔻 Deactivating environment (left project directory)
```

### 场景 2：使用 requirements.txt 的老项目

```bash
# 创建共享环境
uvm create legacy-app --python 3.9

# 进入项目目录
cd ~/projects/legacy-app

# 使用 .uvmrc 链接环境
echo "legacy-app" > .uvmrc

# 安装依赖
pip install -r requirements.txt

# 环境自动激活
cd ~/projects/legacy-app
# 🔄 Auto-activating uvm environment: legacy-app
```

---

## 多 Python 版本

### 跨 Python 版本测试

```bash
# 为不同 Python 版本创建环境
uvm create py38 --python 3.8
uvm create py39 --python 3.9
uvm create py310 --python 3.10
uvm create py311 --python 3.11
uvm create py312 --python 3.12

# 在 Python 3.8 中测试
uvm activate py38
python -m pytest tests/

# 在 Python 3.11 中测试
uvm deactivate
uvm activate py311
python -m pytest tests/

# 列出所有测试环境
uvm list
```

### 开发 vs 生产环境

```bash
# 使用最新 Python 的开发环境
uvm create dev --python 3.12
uvm activate dev
pip install -r requirements-dev.txt  # 包含 pytest, black, mypy

# 使用稳定 Python 的生产环境
uvm create prod --python 3.11
uvm activate prod
pip install -r requirements.txt  # 仅生产依赖
```

---

## 共享环境

### 场景：多项目共享依赖

```bash
# 创建共享的数据科学环境
uvm create ds-common --python 3.11
uvm activate ds-common
pip install numpy pandas matplotlib scikit-learn jupyter

# 项目 1：销售分析
cd ~/projects/sales-analysis
echo "ds-common" > .uvmrc
# 进入时自动激活 ds-common

# 项目 2：客户细分
cd ~/projects/customer-segmentation
echo "ds-common" > .uvmrc
# 进入时自动激活 ds-common

# 两个项目共享同一环境
```

### 场景：学习环境

```bash
# 创建学习环境
uvm create learning --python 3.11
uvm activate learning

# 安装常用学习包
pip install requests beautifulsoup4 flask django

# 创建多个学习项目
mkdir -p ~/learning/web-scraping
cd ~/learning/web-scraping
echo "learning" > .uvmrc

mkdir -p ~/learning/flask-tutorial
cd ~/learning/flask-tutorial
echo "learning" > .uvmrc

# 所有学习项目使用同一环境
```

---

## 从 Conda 迁移

### Conda 与 uvm 命令对照

| Conda 命令 | uvm 等效命令 | 备注 |
|------------|--------------|------|
| `conda create -n myenv python=3.11` | `uvm create myenv --python 3.11` | ✅ |
| `conda activate myenv` | `uvm activate myenv` | 需要 shell-hook |
| `conda deactivate` | `uvm deactivate` | 需要 shell-hook |
| `conda env list` | `uvm list` | ✅ |
| `conda remove -n myenv --all` | `uvm delete myenv` | ✅ |
| `conda install package` | `pip install package` | 使用 pip/uv pip |
| `conda env export` | `pip freeze > requirements.txt` | 手动导出 |

### 迁移示例

**迁移前（Conda）：**

```bash
# 创建环境
conda create -n myproject python=3.11

# 激活
conda activate myproject

# 安装包
conda install numpy pandas matplotlib

# 停用
conda deactivate
```

**迁移后（uvm）：**

```bash
# 创建环境
uvm create myproject --python 3.11

# 激活（启用 shell-hook 后）
uvm activate myproject

# 安装包（使用 UV 更快）
pip install numpy pandas matplotlib
# 或
uv pip install numpy pandas matplotlib

# 停用
uvm deactivate
```

### 导出 Conda 环境到 uvm

```bash
# 在 conda 环境中
conda activate myenv
pip freeze > requirements.txt
conda deactivate

# 创建等效的 uvm 环境
uvm create myenv --python 3.11
uvm activate myenv
pip install -r requirements.txt
```

---

## 高级模式

### 临时测试环境

```bash
# 创建临时环境
uvm create temp-test --python 3.11

# 激活并测试
uvm activate temp-test
pip install some-experimental-package
python test_script.py

# 清理
uvm deactivate
uvm delete temp-test --force
```

### 自定义环境位置

```bash
# 在外部驱动器上创建环境
uvm create bigdata --python 3.11 --path /mnt/external/envs/bigdata

# 仍由 uvm 管理
uvm list  # 显示自定义路径
uvm activate bigdata  # 正常工作
```

### 快速包测试

```bash
# 在一个会话中创建、激活、测试和删除
uvm create test-pkg --python 3.11
uvm activate test-pkg
pip install new-package
python -c "import new_package; print(new_package.__version__)"
uvm deactivate
uvm delete test-pkg --force
```

---

## 技巧和最佳实践

### 1. 项目使用本地 `.venv`

对于使用 `pyproject.toml` 的现代项目，优先使用本地 `.venv`：

```bash
cd ~/projects/myapp
uv venv
uv sync
# 自动激活，无需 .uvmrc
```

### 2. 学习使用共享环境

用于学习和实验时，使用共享环境：

```bash
uvm create learning --python 3.11
# 跨多个学习项目复用
```

### 3. 生产环境锁定 Python 版本

生产环境始终指定 Python 版本：

```bash
uvm create prod-api --python 3.11.5  # 锁定精确版本
```

### 4. 使用 `uv pip` 加速安装

```bash
uvm activate myenv
uv pip install -r requirements.txt  # 比 pip 快得多
```

### 5. 定期清理

```bash
# 列出所有环境
uvm list

# 删除不用的环境
uvm delete old-project --force
uvm delete temp-env --force
```

---

## 故障排除示例

### 问题：环境不自动激活

**解决方法：**

```bash
# 1. 检查 shell-hook 是否启用
grep "uvm shell-hook" ~/.bashrc

# 2. 如果没有，添加它
echo 'eval "$(uvm shell-hook)"' >> ~/.bashrc
source ~/.bashrc

# 3. 测试
cd ~/projects/myapp
# 应该看到：🔄 Auto-activating...
```

### 问题：激活了错误的环境

**解决方法：**

```bash
# 检查当前目录是否有 .venv 或 .uvmrc
ls -la | grep -E "\.venv|\.uvmrc"

# .venv 优先级高于 .uvmrc
# 如果想使用 .venv，删除 .uvmrc
rm .uvmrc
```

### 问题：包安装慢

**解决方法：**

```bash
# 验证镜像配置
cat ~/.config/uv/uv.toml

# 应该显示清华镜像
# 如果没有，重新配置
uvm config mirror set https://pypi.tuna.tsinghua.edu.cn/simple

# 使用 uv pip 代替 pip
uv pip install package  # 快得多
```

---

## 实际工作流

### Web 开发

```bash
# 后端 API
cd ~/projects/backend-api
uv venv
uv pip install fastapi uvicorn sqlalchemy

# 前端（如果使用 Python 工具）
cd ~/projects/frontend
echo "backend-api" > .uvmrc  # 共享后端环境
```

### 数据科学

```bash
# 创建数据科学环境
uvm create ds --python 3.11
uvm activate ds
uv pip install numpy pandas matplotlib seaborn jupyter scikit-learn

# 在多个 notebook 中使用
cd ~/notebooks/analysis1
echo "ds" > .uvmrc

cd ~/notebooks/analysis2
echo "ds" > .uvmrc
```

### 测试和 CI/CD

```bash
# 创建测试环境
uvm create test-py38 --python 3.8
uvm create test-py311 --python 3.11
uvm create test-py312 --python 3.12

# 在每个环境中运行测试
for env in test-py38 test-py311 test-py312; do
    uvm activate $env
    pytest tests/
    uvm deactivate
done
```

---

更多信息请参阅 [README.md](README.md)。
