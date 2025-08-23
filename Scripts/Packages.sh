#!/bin/bash

#安装和更新软件包
UPDATE_PACKAGE() {
	local PKG_NAME=$1
	local PKG_REPO=$2
	local PKG_BRANCH=$3
	local PKG_SPECIAL=$4
	local PKG_LIST=("$PKG_NAME" $5)  # 第5个参数为自定义名称列表
	local REPO_NAME=${PKG_REPO#*/}

	echo " "

	# 删除本地可能存在的不同名称的软件包
	for NAME in "${PKG_LIST[@]}"; do
		# 查找匹配的目录
		echo "Search directory: $NAME"
		local FOUND_DIRS=$(find ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d -iname "*$NAME*" 2>/dev/null)

		# 删除找到的目录
		if [ -n "$FOUND_DIRS" ]; then
			while read -r DIR; do
				rm -rf "$DIR"
				echo "Delete directory: $DIR"
			done <<< "$FOUND_DIRS"
		else
			echo "Not fonud directory: $NAME"
		fi
	done

	# 克隆 GitHub 仓库
	git clone --depth=1 --single-branch --branch $PKG_BRANCH "https://github.com/$PKG_REPO.git"

	# 处理克隆的仓库
	if [[ $PKG_SPECIAL == "pkg" ]]; then
		find ./$REPO_NAME/*/ -maxdepth 3 -type d -iname "*$PKG_NAME*" -prune -exec cp -rf {} ./ \;
		rm -rf ./$REPO_NAME/
	elif [[ $PKG_SPECIAL == "name" ]]; then
		mv -f $REPO_NAME $PKG_NAME
	fi
}

# --- 核心 LuCI 应用 ---
UPDATE_PACKAGE "argon" "sbwml/luci-theme-argon" "openwrt-24.10"
UPDATE_PACKAGE "homeproxy" "VIKINGYFY/homeproxy" "main"

# --- 新增的 LuCI 应用 ---
# 从 kenzok8/small-package 大杂烩仓库添加，使用 "pkg" 参数提取
UPDATE_PACKAGE "luci-app-passwall" "kenzok8/small-package" "main" "pkg" "passwall"
UPDATE_PACKAGE "luci-app-lucky" "kenzok8/small-package" "main" "pkg" "lucky"
UPDATE_PACKAGE "luci-app-ksmbd" "kenzok8/small-package" "main" "pkg" "ksmbd"
UPDATE_PACKAGE "luci-app-mosdns" "kenzok8/small-package" "main" "pkg" "mosdns v2dat"
UPDATE_PACKAGE "luci-app-adguardhome" "kenzok8/small-package" "main" "pkg" "AdGuardHome"

# 从独立的仓库添加
UPDATE_PACKAGE "luci-app-einat" "muink/luci-app-einat" "master" "" "einat"


# --- 其他原有插件 ---
UPDATE_PACKAGE "ddns-go" "sirpdboy/luci-app-ddns-go" "main"
UPDATE_PACKAGE "easytier" "EasyTier/luci-app-easytier" "main"
UPDATE_PACKAGE "partexp" "sirpdboy/luci-app-partexp" "main"
UPDATE_PACKAGE "viking" "VIKINGYFY/packages" "main" "" "luci-app-timewol luci-app-wolplus"
UPDATE_PACKAGE "luci-app-daed" "QiuSimons/luci-app-daed" "master"
UPDATE_PACKAGE "luci-app-pushbot" "zzsj0928/luci-app-pushbot" "master"


#更新软件包版本 (此功能未启用)
UPDATE_VERSION() {
	# ... (函数内容保持不变)
}

#UPDATE_VERSION "sing-box"
#UPDATE_VERSION "tailscale"



#不编译xray-core
# sed -i 's/+xray-core//' luci-app-passwall2/Makefile  # 这是针对 passwall2 的，passwall 不需要

#删除官方的默认插件 (重要：增加了 AdGuardHome 以防冲突)
rm -rf ../feeds/luci/applications/luci-app-{passwall*,mosdns,dockerman,dae*,bypass*,AdGuardHome}
rm -rf ../feeds/packages/net/{v2ray-geodata,dae*}

#更新golang为最新版
rm -rf ../feeds/packages/lang/golang
git clone -b 24.x https://github.com/sbwml/packages_lang_golang ../feeds/packages/lang/golang


cp -r $GITHUB_WORKSPACE/package/* ./

#coremark修复
sed -i 's/mkdir \$(PKG_BUILD_DIR)\/\$(ARCH)/mkdir -p \$(PKG_BUILD_DIR)\/\$(ARCH)/g' ../feeds/packages/utils/coremark/Makefile

#修改字体
argon_css_file=$(find ./luci-theme-argon/ -type f -name "cascade.css")
sed -i "/^.main .main-left .nav li a {/,/^}/ { /font-weight: bolder/d }" $argon_css_file
sed -i '/^\[data-page="admin-system-opkg"\] #maincontent>.container {/,/}/ s/font-weight: 600;/font-weight: normal;/' $argon_css_file

#修复daed/Makefile
rm -rf luci-app-daed/daed/Makefile && cp -r $GITHUB_WORKSPACE/patches/daed/Makefile luci-app-daed/daed/
cat luci-app-daed/daed/Makefile
