# config.py

MONGODB_URL = "mongodb://localhost:27017"
DATABASE_NAME = "fox_market"
# Add other configuration variables as needed, e.g.:
# SECRET_KEY = "your-secret-key" 

SQLALCHEMY_DATABASE_URL = "mysql+pymysql://foxuser:secretpass@localhost:3306/foxdb"

# Redis Configuration for Epic 1
REDIS_URL = "redis://localhost:6379/0"

# CLOB Fee Configuration (as percentages)
MAKER_FEE_PERCENTAGE = 0.001  # 0.1% for makers (liquidity providers)
TAKER_FEE_PERCENTAGE = 0.002  # 0.2% for takers (market orders)

# Logging level configuration
import logging
LOG_LEVEL = logging.INFO  # Default to INFO

# Web3 HTTP provider URL
# WEB3_HTTP_PROVIDER_URL = "https://eth-sepolia.g.alchemy.com/v2/-rsjK7DC1rJZmD3vro4_AUTEK26wFwFr"
WEB3_HTTP_PROVIDER_URL = "http://localhost:7545"

import os

DEPLOYER_PRIVATE_KEY = os.environ.get("DEPLOYER_PRIVATE_KEY", "0xb9ad02245ee24d992f9fd7216f9729251f9defdec940f9b97fdfd7b173bca19f")
DEPLOYER_ACCOUNT_ADDRESS = os.environ.get("DEPLOYER_ACCOUNT_ADDRESS", "0xB6f0bf48ACf3Edc3d86717B5819640dA7F078B3B")

# Epic 1 Configuration
ORDER_BOOK_CACHE_TTL = 300  # 5 minutes cache TTL
ORDER_BOOK_UPDATE_INTERVAL = 1  # 1 second update interval
MAX_ORDER_BOOK_DEPTH = 10  # Top 10 bids/asks
