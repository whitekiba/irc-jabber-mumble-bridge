Bridge-v2

INTEGRATE ALL TEH THINGS!

This is v2 of our multi-messenger IM bridge. 

It was an internal project for a long time. It started as a learning project so some classes need cleanup.

If you found a bug: Fix it!

If you found hardcoded Stuff: Tell me.

How it works:

The bridge listens on all configured channels and collects all messages and events and broadcasts them to all other connected channels.

Supported networks:
- IRC
- Telegram
- Jabber
- Mumble
- Teamspeak

Used technologies:
- Ruby
- Redis
- MariaDB

<b>install</b>

We recommend rvm (https://rvm.io). It makes managing dependencies easier

1. clone this repository
2. gem install bundler
3. bundle install
4. ruby bridge.rb (bridged not working)

TODO:
 - improve documentation
 - Fix bugs
 - Make the assistant process for configuring the bridge usable