# syntax=docker/dockerfile:experimental
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
    libcurl4-openssl-dev \
    git \
    ssh && \
    apt-get clean && \
    rm -r /var/lib/apt/lists/*

# アプリケーションの実行ディレクトリを作成
RUN mkdir /techpitgram
# 実行時のディレクトリに指定
WORKDIR /techpitgram

# Railsとして起動するための依存ライブラリをインストール
COPY Gemfile /techpitgram/Gemfile
COPY Gemfile.lock /techpitgram/Gemfile.lock

# GitHub へのアクセスをするために公開鍵情報を整備
RUN git config --global url.ssh://git@github.com.insteadOf "https://github.com" && \
  mkdir -p -m 0600 ~/.ssh && ssh-keyscan github.com >> ~/.ssh/known_hosts
RUN --mount=type=ssh bundle install

# アプリケーションをコピー
COPY . /techpitgram

FROM techpitgram-depends-all as techpitgram-build-assets

# assetのビルド
RUN bundle exec rails assets:precompile

FROM techpitgram-depends-all as techpitgram-app

# ビルドした asset をコピーする
COPY --from=techpitgram-build-assets /techpitgram/public/assets /techpitgram/public

# コンテナの起動時に実行したいスクリプト指定
COPY tools/entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]

# Railsを起動
EXPOSE 3000
CMD ["rails", "server", "-b", "0.0.0.0"]