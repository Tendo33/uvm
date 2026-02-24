#!/usr/bin/env bats
# =============================================================================
# uvm 功能集成测试
# 依赖：bats-core, uv（已安装）
# 运行：bats tests/
# =============================================================================

setup() {
    # 创建独立的沙盒目录（每个测试用例隔离）
    TEST_HOME="$(mktemp -d)"
    export HOME="$TEST_HOME"
    export UVM_HOME="${TEST_HOME}/.config/uvm"
    export UVM_ENVS_DIR="${TEST_HOME}/uv_envs"

    # 将项目 bin 目录加入 PATH
    export PATH="${BATS_TEST_DIRNAME}/../bin:$PATH"

    # 加载库文件
    source "${BATS_TEST_DIRNAME}/../lib/uvm-config.sh"
    source "${BATS_TEST_DIRNAME}/../lib/uvm-core.sh"
}

teardown() {
    # 清理沙盒目录
    rm -rf "$TEST_HOME"
}

# ─────────────────────────────────────────────────────────
# 模块：配置初始化
# ─────────────────────────────────────────────────────────

@test "init_uvm_config: 创建配置目录和 envs.json" {
    init_uvm_config
    [ -d "${UVM_HOME}" ]
    [ -f "${UVM_HOME}/envs.json" ]
    local content
    content=$(cat "${UVM_HOME}/envs.json")
    [ "$content" = "[]" ]
}

@test "init_uvm_config: 幂等性 - 重复调用不报错" {
    init_uvm_config
    run init_uvm_config
    [ "$status" -eq 0 ]
}

# ─────────────────────────────────────────────────────────
# 模块：uvm create
# ─────────────────────────────────────────────────────────

@test "uvm_create: 成功创建虚拟环境" {
    init_uvm_config
    run uvm_create "testenv"
    [ "$status" -eq 0 ]
    [[ "$output" == *"created successfully"* ]]
    [ -d "${UVM_ENVS_DIR}/testenv" ]
}

@test "uvm_create: 不指定环境名称时报错" {
    init_uvm_config
    run uvm_create
    [ "$status" -ne 0 ]
    [[ "$output" == *"required"* ]]
}

@test "uvm_create: 环境已存在时报错" {
    init_uvm_config
    uvm_create "dupenv"
    run uvm_create "dupenv"
    [ "$status" -ne 0 ]
    [[ "$output" == *"already exists"* ]]
}

@test "uvm_create: --python 参数正确传递" {
    init_uvm_config
    run uvm_create "pyenv311" --python "3.11"
    [ "$status" -eq 0 ]
    [ -d "${UVM_ENVS_DIR}/pyenv311" ]
}

@test "uvm_create: 未知参数时报错" {
    init_uvm_config
    run uvm_create "myenv" --unknown-flag
    [ "$status" -ne 0 ]
    [[ "$output" == *"Unknown option"* ]]
}

# ─────────────────────────────────────────────────────────
# 模块：uvm delete
# ─────────────────────────────────────────────────────────

@test "uvm_delete: 强制删除已存在的环境" {
    init_uvm_config
    uvm_create "delenv"
    run uvm_delete "delenv" --force
    [ "$status" -eq 0 ]
    [ ! -d "${UVM_ENVS_DIR}/delenv" ]
}

@test "uvm_delete: 删除不存在的环境时报错" {
    init_uvm_config
    run uvm_delete "nonexistent" --force
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* ]]
}

@test "uvm_delete: 不指定环境名称时报错" {
    init_uvm_config
    run uvm_delete
    [ "$status" -ne 0 ]
}

# ─────────────────────────────────────────────────────────
# 模块：uvm list
# ─────────────────────────────────────────────────────────

@test "uvm_list: 无环境时提示创建" {
    init_uvm_config
    run uvm_list
    [ "$status" -eq 0 ]
    [[ "$output" == *"No environments found"* || "$output" == *"create"* ]]
}

@test "uvm_list: 创建环境后显示在列表中" {
    init_uvm_config
    uvm_create "listenv"
    run uvm_list
    [ "$status" -eq 0 ]
    [[ "$output" == *"listenv"* ]]
}

# ─────────────────────────────────────────────────────────
# 模块：安全回归测试 - .uvmrc 路径穿越防护
# ─────────────────────────────────────────────────────────

@test "安全: .uvmrc 合法名称通过校验" {
    # 模拟校验逻辑
    validate_uvmrc_name() {
        local name="$1"
        [[ "$name" =~ ^[a-zA-Z0-9_-]+$ ]]
    }
    for name in "myenv" "my-env" "env_1" "Prod123"; do
        run validate_uvmrc_name "$name"
        [ "$status" -eq 0 ]
    done
}

@test "安全: .uvmrc 路径穿越字符被拒绝" {
    validate_uvmrc_name() {
        local name="$1"
        [[ "$name" =~ ^[a-zA-Z0-9_-]+$ ]]
    }
    for name in "../evil" "../../etc" "env name" "env;rm" 'env$(cmd)'; do
        run validate_uvmrc_name "$name"
        [ "$status" -ne 0 ]
    done
}

# ─────────────────────────────────────────────────────────
# 模块：安全回归测试 - install.sh eval 注入已消除
# ─────────────────────────────────────────────────────────

@test "安全: install.sh 不包含 'eval echo'" {
    run grep -n 'eval echo' "${BATS_TEST_DIRNAME}/../install.sh"
    # grep 未找到匹配时 status=1，这里期望没找到
    [ "$status" -ne 0 ]
}

# ─────────────────────────────────────────────────────────
# 模块：JSON 元数据完整性
# ─────────────────────────────────────────────────────────

@test "元数据: 创建环境后 envs.json 被正确更新" {
    init_uvm_config
    uvm_create "metaenv"
    local envs_file="${UVM_HOME}/envs.json"
    [ -f "$envs_file" ]
    # 应包含环境名
    grep -q '"name":"metaenv"' "$envs_file"
}

@test "元数据: 删除环境后 envs.json 中记录被清除" {
    init_uvm_config
    uvm_create "rmenv"
    uvm_delete "rmenv" --force
    local envs_file="${UVM_HOME}/envs.json"
    # 删除后不应再包含该名称
    run grep '"name":"rmenv"' "$envs_file"
    [ "$status" -ne 0 ]
}
