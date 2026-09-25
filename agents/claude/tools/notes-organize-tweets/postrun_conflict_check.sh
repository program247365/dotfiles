#!/bin/bash
sqlite3 -readonly ~/Library/Group\ Containers/9K33E3U3T4.net.shinyfrog.bear/Application\ Data/database.sqlite \
  "SELECT ZUNIQUEIDENTIFIER FROM ZSFNOTE WHERE ZCONFLICTUNIQUEIDENTIFIER IS NOT NULL AND ZTRASHED=0"
