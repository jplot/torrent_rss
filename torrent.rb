require 'sinatra'
require 'net/http'
require 'cgi'
require 'rss/maker'

COOKIE_PATH = File.join(ENV['HOME'], 'cookies')

def make_feed_idem(maker, torrent)
  maker.items.new_item do |item|
    item.link = torrent[:link]
    # item.enclosures = RSS::Rss::Channel::Item::Enclosure.new
    # item.enclosures.url = torrent[:link]
    item.title = torrent[:name]
    item.description = torrent[:name]
    item.date = torrent[:published]
  end
end

def make_feed(title, description, link, items)
  RSS::Maker.make('2.0') do |maker|
    maker.channel.title = title
    maker.channel.description = description
    maker.channel.link = link
    maker.items.do_sort = true

    items.each do |torrent|
      make_feed_idem(maker, torrent)
    end
  end.to_s
end

def escape_tag(xml, tag)
  xml.gsub(%r{<#{tag}>(.*?)<\/#{tag}>}) do |s|
    matches = s.match(%r{<#{tag}>(.*?)<\/#{tag}>})
    content = CGI.escapeHTML(CGI.unescapeHTML(matches[1]))
    "<#{tag}>#{content}</#{tag}>"
  end
end

def parse_feed(url)
  rss_response = Net::HTTP.get_response(URI(url))
  rss_body = escape_tag(rss_response.body, 'title')
  rss_body = escape_tag(rss_body, 'description')

  RSS::Parser.parse(rss_body, false)
end

get '/', provides: 'text' do
end

get '/ygg', provides: 'rss' do
  rss_channel = parse_feed("https://www2.yggtorrent.ch/rss?action=generate&type=cat&id=2145&passkey=#{ENV.fetch('YGG_PASSKEY')}")
  items = rss_channel.items.map do |item|
    { name: item.title, link: item.enclosure.url, published: item.pubDate }
  end

  content_type :rss, charset: 'UTF-8'
  make_feed('YggTorrent', 'YggTorrent RSS feed', 'https://www2.yggtorrent.ch/', items)
end

get '/eztv', provides: 'rss' do
  rss_channel = parse_feed('https://eztv.ag/ezrss.xml')
  items = rss_channel.items.map do |item|
    { name: item.title, link: item.enclosure.url, published: item.pubDate }
  end

  content_type :rss, charset: 'UTF-8'
  make_feed('EZTV', 'EZTV RSS feed', 'https://eztv.ag/', items)
end
