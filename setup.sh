#!/bin/sh

# 接続先のサーバー情報
server=lolipop

# テンプレートを置いておくディレクトリ
templateDir=git
openDir=test
secretDir=test
wpDir=wp



#==================================
# functions
#==================================

temp(){

  #一時的なフォルダを作成する
  temp_file=$(mktemp)
  temp_dir=$(mktemp -d)
  trap "
  rm $temp_file
  rm -rf $temp_dir
  " 0

}

ls_dir(){

  #サーバー側のディレクトリを見る
  echo "
  ${1:-$secretDir}ディレクトリ
  ----------------------------
  "
  ssh $server command "cd ${1:-$secretDir};ls"
  echo "
  ----------------------------
  "

}

gitcall () {

  # template set up
  git clone ssh://$server/~/${templateDir}/$1 $2
  cd ./$2/
  rm -rf .git
  git init
  git add .
  git commit -m "First commit"

}


rm_site(){

  # サーバーにあるRepositoryを削除
  ssh $server command "
  cd ~/web/${openDir}/;
  rm -rf $1;
  cd ~/${secretDir}/;
  rm -rf $1"
  echo "${1}を削除しました。"

}

repository_setup(){

  # サーバーにRepositoryを追加
  ssh $server command "
  cd ~/${secretDir};
  mkdir ${1};
  cd ${1};
  git init --bare --shared;"
  ssh $server command "cd ~/${secretDir}/${1}/hooks;
cat << 'EOF' > post-receive
#/bin/bash

cd ~/web/${openDir}/${1}
git --git-dir=.git pull origin develop:develop

EOF"
  ssh $server command "cd ~/${secretDir}/${1}/hooks;
  chmod 744 post-receive;
  "

  # サーバーの公開領域にRepositoryを追加
  ssh $server command "
  cd ~/web/${openDir};
  mkdir ${1};
  cd ${1};
  git init;
  git remote add origin ~/${secretdir}/${1}
  "
  echo "${1}を設定しました。
  url : http:basicexe.main.jp/test/${1}/"

}

repository_add(){

  # リモートリポジトリtestを追加
  git remote add test ssh://${server}/~/${secretdir}/$1
  echo "リポジトリをtestとして追加しました。"

}

wp_cil_install(){
  ssh $server command "
  mkdir bin;
  "
  temp
  cd $temp_dir

cat <<'_EOF_' > .bash_profile
export PATH="~/bin:$PATH"
_EOF_

  scp ./.bash_profile $server:~/

  ssh $server command "
  source .bash_profile;
  curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar;
  php wp-cli.phar --info;
  chmod +x wp-cli.phar;
  mv wp-cli.phar ~/bin/wp;
  wp --version
  "
  echo "wp cliをインストールしました。"
}

help(){
  echo "
  リポジトリの設定などセットアップを行うシェルスクリプトです。
  どのようなセットアップを行うか選択してください。

  ［メニュー］

  ---サーバーセットアップ

  wp-cli    install : wp-cli

  wordpress set up
  site      set up  : test
  site      remove  : remove

  ---ローカルセットアップ

  template  set up  : call
  add   repository  : remote
  template add repository  : calladd
  "
  ls_dir
}

#==================================
# 判定・処理
#==================================
case "$1" in
  "call")
    ls_dir $templateDir
    read -p "Please template file name: " template
    read -p "Please input file name: " fileName
    gitcall $template $fileName
    ;;
  "calladd")
    ls_dir $templateDir
    read -p "Please template file name: " template
    read -p "Please input file name: " fileName
    gitcall $template $fileName
    repository_add $fileName
    ;;
  "remove")
    ls_dir
    read -p "Please delete template file : " template
    rm_site $template
    ls_dir
    ;;
  "test")
    ls_dir
    read -p "Please delete template file : " template
    repository_setup $template
    ;;
  "remote")
    ls_dir
    read -p "Please add template file : " template
    repository_add $template
    ;;
  "wp")

    ;;
  "wp-cli")
    wp_cil_install
    ;;
  *)
    help
esac

