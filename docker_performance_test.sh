#!/bin/bash
set -eu
here="$(cd "$(dirname "${BASH_SOURCE:-$0}")"; pwd)"
testdir="$here/testdir"
repo='https://github.com/ros-planning/navigation'

if [[ -d $testdir ]]; then
    # なんか既にテスト用ディレクトリあるな...
    echo "$testdir: The directory already exists." >&2
    exit 1
fi

# 後片付け用関数
function rm_on_exit() {
    # 後片付け
    if [[ -n ${cid:-} ]]; then
        # コンテナ起動していたら止める(権限の関係でとりあえずホームディレクトリ以下全部消しておく)
        docker exec -it "$cid" /bin/bash -c 'rm -rf /root/*' &>/dev/null || true
        docker stop "$cid"
    fi
    # 作った一時ディレクトリの削除
    rm -rf "$testdir"
}
trap 'rm_on_exit' 0 1 2 3 15

# コンテナのビルド
env DOCKER_BUILDKIT=1 docker build -t docker_perf_tester "$here"

# テスト用ディレクトリの作成とテストビルド用ROSパッケージリポジトリのクローン
mkdir -p "$testdir/catkin_ws_01/src"
git clone -b noetic-devel "$repo" "$testdir/catkin_ws_01/src/navigation"
git clone -b noetic-devel "$repo" "$testdir/navigation"

# テスト用コンテナの起動
docker run -itd --rm \
    --cidfile "$testdir/cid" \
    --volume "$testdir/catkin_ws_01:/root/catkin_ws_01" \
    --volume "$testdir/navigation:/root/catkin_ws_02/src/navigation" \
    docker_perf_tester \
    /bin/bash

# コンテナIDの取得
cid="$(cat -- "$testdir/cid")"

# 完全にコンテナ内だけで完結するように
docker exec -it "$cid" /bin/bash -c "mkdir -p /root/catkin_ws_03/src; git clone '$repo' /root/catkin_ws_03/src/navigation"

# ビルドと時間計測
start="$(date +%s)"
docker exec -it "$cid" /bin/bash -c 'source /opt/ros/$ROS_DISTRO/setup.bash; catkin build -w "/root/catkin_ws_01"'
ws01_end="$(date +%s)"
docker exec -it "$cid" /bin/bash -c 'source /opt/ros/$ROS_DISTRO/setup.bash; catkin build -w "/root/catkin_ws_02"'
ws02_end="$(date +%s)"
docker exec -it "$cid" /bin/bash -c 'source /opt/ros/$ROS_DISTRO/setup.bash; catkin build -w "/root/catkin_ws_03"'
ws03_end="$(date +%s)"

# かかった時間計測
ws01_time="$(( ws01_end - start ))"
ws02_time="$(( ws02_end - ws01_time ))"
ws03_time="$(( ws03_end - ws02_time ))"

echo
echo "test01: $(( ws01_time / 60 )) mins $(( ws01_time % 60)) secs"
echo "test02: $(( ws02_time / 60 )) mins $(( ws02_time % 60)) secs"
echo "test03: $(( ws03_time / 60 )) mins $(( ws03_time % 60)) secs"
