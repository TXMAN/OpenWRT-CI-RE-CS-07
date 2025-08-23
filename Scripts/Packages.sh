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

# --- 基础和主题 ---
UPDATE_PACKAGE "argon" "sbwml/luci-theme-argon" "openwrt-24.10"
#UPDATE_PACKAGE "kucat" "sirpdboy/luci-theme-kucat" "js"

# --- 原有插件 ---
UPDATE_PACKAGE "homeproxy" "VIKINGYFY/homeproxy" "main"
UPDATE_PACKAGE "nikki" "nikkinikki-org/OpenWrt-nikki" "main"
UPDATE_PACKAGE "momo" "nikkinikki-org/OpenWrt-momo" "main"
UPDATE_PACKAGE "ddns-go" "sirpdboy/luci-app-ddns-go" "main"
UPDATE_PACKAGE "easytier" "EasyTier/luci-app-easytier" "main"
UPDATE_PACKAGE "gecoosac" "lwb1978/openwrt-gecoosac" "main"
UPDATE_PACKAGE "netspeedtest" "sirpdboy/luci-app-netspeedtest" "js" "" "homebox speedtest"
UPDATE_PACKAGE "partexp" "sirpdboy/luci-app-partexp" "main"
UPDATE_PACKAGE "viking" "VIKINGYFY/packages" "main" "" "luci-app-timewol luci-app-wolplus"
UPDATE_PACKAGE "luci-app-daed" "QiuSimons/luci-app-daed" "master"
UPDATE_PACKAGE "luci-app-pushbot" "zzsj0928/luci-app-pushbot" "master"

# --- 【新增】LuCI 应用 (前端界面) ---
UPDATE_PACKAGE "luci-app-passwall" "kenzok8/small-package" "main" "pkg"
UPDATE_PACKAGE "luci-app-lucky" "kenzok8/small-package" "main" "pkg"
UPDATE_PACKAGE "luci-app-ksmbd" "kenzok8/small-package" "main" "pkg"
UPDATE_PACKAGE "luci-app-mosdns" "kenzok8/small-package" "main" "pkg"
UPDATE_PACKAGE "luci-app-adguardhome" "kenzok8/small-package" "main" "pkg"
UPDATE_PACKAGE "luci-app-einat" "muink/luci-app-einat" "master"

# --- 【新增】LuCI 应用所需的核心程序 (后端引擎) ---
UPDATE_PACKAGE "adguardhome" "kenzok8/small-package" "main" "pkg"
UPDATE_PACKAGE "lucky" "kenzok8/small-package" "main" "pkg"
UPDATE_PACKAGE "mosdns" "kenzok8/small-package" "main" "pkg"
UPDATE_PACKAGE "v2dat" "kenzok8/small-package" "main" "pkg"
UPDATE_PACKAGE "einat-ebpf" "muink/openwrt-einat-ebpf" "main"


#更新软件包版本
UPDATE_VERSION() {
	local PKG_NAME=$1
	local PKG_MARK=${2:-false}
	local PKG_FILES=$(find ./ ../feeds/packages/ -maxdepth 3 -type f -wholename "*/$PKG_NAME/Makefile")

	if [ -z "$PKG_FILES" ]; then
		echo "$PKG_NAME not found!"
		return
	fi

	echo -e "\n$PKG_NAME version update has started!"

	for PKG_FILE in $PKG_FILES; do
		local PKG_REPO=$(grep -Po "PKG_SOURCE_URL:=https://.*github.com/\K[^/]+/[^/]+(?=.*)" $PKG_FILE)
		local PKG_TAG=$(curl -sL "https://api/github.com/repos/$PKG_REPO/releases" | jq -r "map(select(.prerelease == $PKG_MARK)) | first | .tag_name")

		local OLD_VER=$(grep -Po "PKG_VERSION:=\K.*" "$PKG_FILE")
		local OLD_URL=$(grep -Po "PKG_SOURCE_URL:=\K.*" "$PKG_FILE")
		local OLD_FILE=$(grep -Po "PKG_SOURCE:=\K.*" "$PKG_FILE")
		local OLD_HASH=$(grep -Po "PKG_HASH:=\K.*" "$PKG_FILE")

		local PKG_URL=$([[ $OLD_URL == *"releases"* ]] && echo "${OLD_URL%/}/$OLD_FILE" || echo "${OLD_URL%/}")

		local NEW_VER=$(echo $PKG_TAG | sed -E 's/[^0-9]+/\./g; s/^\.|\.$//g')
		local NEW_URL=$(echo $PKG_URL | sed "s/\$(PKG_VERSION)/$NEW_VER/g; s/\$(PKG_NAME)/$PKG_NAME/g")
		local NEW_HASH=$(curl -sL "$NEW_URL" | sha256sum | cut -d ' ' -f 1)

		echo "old version: $OLD_VER $OLD_HASH"
		echo "new version: $NEW_VER $NEW_HASH"

		if [[ $NEW_VER =~ ^[0-9].* ]] && dpkg --compare-versions "$OLD_VER" lt "$NEW_VER"; then
			sed -i "s/PKG_VERSION:=.*/PKG_VERSION:=$NEW_VER/g" "$PKG_FILE"
			sed -i "s/PKG_HASH:=.*/PKG_HASH:=$NEW_HASH/g" "$PKG_FILE"
			echo "$PKG_FILE version has been updated!"
		else
			echo "$PKG_FILE version is already the latest!"
		fi
	done
}

#UPDATE_VERSION "软件包名" "测试版，true，可选，默认为否"
#UPDATE_VERSION "sing-box"
#UPDATE_VERSION "tailscale"



#不编译xray-core
# sed -i 's/+xray-core//' luci-app-passwall2/Makefile

#删除官方的默认插件 (已增加 AdGuardHome 防止冲突)
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
sed -i '/^\[data-page="admin-system-opkg"\
