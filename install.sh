#!/bin/sh
curl -L http://cpanmin.us | perl - --sudo App::cpanminus
sudo cpanm Algorithm::Diff
sudo -u postgres psql -f install.sql
