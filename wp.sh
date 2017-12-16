#!/bin/sh


# 設定ファイルをこのように設定してください
# 
# 接続先のサーバー情報
# server=hoge
# 
# テンプレートを置いておくディレクトリ
# templateDir=template
# templateName=hoge
# wp_secretDir=hoge
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
  ${1:-$wp_secretDir}ディレクトリ
  ----------------------------
  "
  ssh $server command "cd ${1:-$wp_secretDir};ls"
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

loop(){
  # ファイル一覧を取得して複数回処理を繰り替えす
files=$(ssh lolipop command "ls ~/template/")
for file in ${files}; do
  echo "${file}"
done
}


gitcall () {

  # template set up
  git clone ssh://$server/~/${templateDir}/${templateName} $1
  cd ./$1/
  rm -rf .git
  git init
  git add .
  git commit -m "First commit"

}


rm_site(){

  # サーバーにあるRepositoryを削除
  ssh $server command "
  cd ~/web/${wp_openDir}/;
  rm -rf $1;
  cd ~/${wp_secretDir}/;
  rm -rf $1"
  echo "${1}を削除しました。"

}


repository_setup(){

  # サーバーにRepositoryを追加
  ssh $server command "
  cd ~/${wp_secretDir};
  mkdir ${1};
  cd ${1};
  git init --bare --shared;"
  ssh $server command "cd ~/${wp_secretDir}/${1}/hooks;
cat << 'EOF' > post-receive
#!/bin/bash

cd ~/web/${wp_openDir}/${1}
git --git-dir=.git pull origin develop:develop

EOF"
  ssh $server command "cd ~/${wp_secretDir}/${1}/hooks;
  chmod 775 post-receive;
  "

  # サーバーの公開領域にRepositoryを追加
  ssh $server command "
  cd ~/web/${wp_openDir};
  mkdir ${1};
  cd ${1};
  git init;
  git remote add origin ~/${wp_secretDir}/${1}
  "
  echo "${1}を設定しました。
  url : http:basicexe.main.jp/${wp_secretDir}/${1}/"

}

repository_add(){

  # リモートリポジトリtestを追加
  git remote add test ssh://${server}/~/${wp_secretDir}/$1
  echo "リポジトリをtestとして追加しました。"

}

install(){
  ssh $server command "
  cd ~/web/${wp_openDir}/;
  mkdir $1;
  cd ~/web/${wp_openDir}/$1;
  ~/bin/wp core download --locale=ja;
  ~/bin/wp core config --dbname=${db_name} --dbuser=${db_user} --dbpass=${db_pass} --dbhost=${db_host} --dbprefix=${1}_ ;
  ~/bin/wp core install --url=${wp_url}${wp_openDir}/${1} --title=${wp_title} --admin_user=${wp_user} --admin_password=${wp_pass} --admin_email=${wp_email}
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
  リポジトリの設定などセットアップを行うシェルスクリプトです。
  どのようなセットアップを行うか選択してください。

  ［メニュー］

  ---サーバーセットアップ

  wp-cli    install : wp-cli

  wordpress set up
  site      set up  : up
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
    ls_dir
    read -p "Please file name: " fileName
    echo "${fileName}としてセットアップしますか？"
    yn
    gitcall $fileName
    ;;
  "remove")
    ls_dir
    read -p "Please delete template file : " template
    echo "本当に${template}を削除しますか？"
    yn
    rm_site $template
    ;;
  "setup")
    ls_dir
    read -p "Please delete template file : " template
    echo "${template}としてリモートを設定しgitにtestを追加します。"
    yn
    repository_setup $template
    repository_add $template
    ;;
  "install")
    read -p "Please install site : " template
    echo "wordpressを${template}としてセットアップしますか？"
    yn
    install ${template}
    ;;
  "wp-cli")
    echo "wp-cliをインストールしますか？"
    yn
    wp_cil_install
    ;;
  *)
    help
esac

