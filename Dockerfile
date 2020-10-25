# ベースイメージを選定する
FROM ruby:2.5.1-slim-stretch as techpitgram-depends-all

RUN apt-get update -qq && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y  --no-install-recommends \
    imagemagick \
    build-essential \
    patch \
    ruby-dev \
    zlib1g-dev \
    liblzma-dev \
    libxml2-dev \
    libpq-dev \
    libcurl4-openssl-dev && \
  apt-get -y clean && \
  rm -rf /var/lib/apt/list/*

# アプリケーションの実行ディレクトリを作成
RUN mkdir /techpitgram
# 実行時のディレクトリに指定
WORKDIR /techpitgram

# Railsとして起動するための依存ライブラリをインストール
COPY Gemfile /techpitgram/Gemfile
COPY Gemfile.lock /techpitgram/Gemfile.lock
RUN bundle install && \
  curl -sL https://deb.nodesource.com/setup_10.x | bash - && \
  apt-get install -y nodejs

# アプリケーションをコピー
COPY . /techpitgram

# assetのビルド
RUN bundle exec rails assets:precompile

FROM ruby:2.5.1-slim-stretch as techpitgram-app

RUN apt-get update -qq && \
DEBIAN_FRONTEND=noninteractive apt-get install -y  --no-install-recommends \
    imagemagick \
    libxml2 \
    libpq-dev && \
  rm -rf /var/lib/apt/list/* && \
  rm -r /usr/local/bundle

# root以外のユーザーに切り替えられるようにする
RUN useradd -d /techpitgram -s /bin/bash techpitgram

# ビルドした bundle をコピーする
COPY --from=techpitgram-depends-all /usr/local/bundle /usr/local/bundle

# ビルドした app をコピーする
COPY --chown=techpitgram:techpitgram --from=techpitgram-depends-all /techpitgram /techpitgram

# 実行時のディレクトリに指定
WORKDIR /techpitgram

# コンテナの起動時に実行したいスクリプト指定
COPY --chown=techpitgram:techpitgram tools/entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]

# root以外のユーザーに切り替えられるようにする
USER techpitgram

# Railsを起動
EXPOSE 3000
CMD ["rails", "server", "-b", "0.0.0.0"]