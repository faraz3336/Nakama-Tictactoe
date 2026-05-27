FROM heroiclabs/nakama:3.20.0

COPY data/modules /nakama/data/modules
COPY deploy/start-nakama.sh /nakama/start-nakama.sh

RUN chmod +x /nakama/start-nakama.sh

EXPOSE 7350 7351 10000 10001

ENTRYPOINT ["/nakama/start-nakama.sh"]
