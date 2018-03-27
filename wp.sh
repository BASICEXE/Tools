#!/bin/sh


# 設定ファイルをこのように設定してください
# 
# 接続先のサーバー情報
# server=hoge
# 
# テンプレートを置いておくディレクトリ
# wp_openDir=hoge
# 
# db_host=hoge
# db_name=hoge
# db_user=hoge
# db_pass=hoge
# 
# wp_url=hoge
# wp_title=hoge
# wp_user=hoge
# wp_email=hoge
# wp_pass=hoge



# 設定ファイルを読み込み
. ./setting/wp_conf

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
  ${1:-$wp_openDir}ディレクトリ
  ----------------------------
  "
  ssh $server command "cd ~/web/${1:-$wp_openDir};ls"
  echo "
  ----------------------------
  "
}

yn(){
  read -p '実行しますか？ [y/n]' yn
  case $yn in
    [Yy] ) break;;
    * ) echo "実行をキャンセルしました。"; exit ;;
  esac
}

install(){
  ssh $server command "
  cd ~/web/${wp_openDir}/;
  mkdir $1;
  cd ~/web/${wp_openDir}/$1;
  ~/bin/wp core download --locale=ja;
  ~/bin/wp core config --dbname=${db_name} --dbuser=${db_user} --dbpass=${db_pass} --dbhost=${db_host} --dbprefix=${1}_ ;
  ~/bin/wp core install --url=${wp_url}${wp_openDir}/${1} --title=${wp_title} --admin_user=${wp_user} --admin_password=${wp_pass} --admin_email=${wp_email};
  ~/bin/wp plugin delete hello;
  ~/bin/wp plugin install all-in-one-wp-migration;
  ~/bin/wp plugin activate all-in-one-wp-migration
  "
}

remove(){
  ssh $server command "
  cd ~/web/${wp_openDir}/$1;
  ~/bin/wp db drop --yes;
  cd ../;
  rm -r /$1;
  "
}

update(){
  files=$(ssh lolipop command "ls ~/web/${wp_openDir}/")
  for file in ${files}; do
    ssh $server command "
    cd ~/web/${wp_openDir}/${files}/;
    ~/bin/wp core update&&
      ~/bin/wp core update-db;
    ~/bin/wp plugin update --all &&
      ~/bin/wp theme update --all &&
      ~/bin/wp core language update;
    ~/bin/wp core verify-checksums
    "
  done
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
  wordpressのテスト環境を自動化するシェルスクリプトです。
  なにを行うか選択してください。

  ［メニュー］

  wp-cli    install    : wp-cli

  wordpress install    : install
  wordpress remove     : remove
  wordpress all update : update

  "
  ls_dir
}

#==================================
# 判定・処理
#==================================
case "$1" in
  "remove")
    ls_dir
    read -p "Please delete site name : " template
    echo "本当に${template}を削除しますか？"
    yn
    remove $template
    ;;
  "install")
    read -p "Please install site : " template
    echo "wordpressを${template}としてセットアップしますか？"
    yn
    install ${template}
    ;;
  "update")
    echo "すべてのwordpressをアップデートしますか？"
    yn
    update
    ;;

  "wp-cli")
    echo "wp-cliをインストールしますか？"
    yn
    wp_cil_install
    ;;
  *)
    help
esac

