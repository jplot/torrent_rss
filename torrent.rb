require 'sinatra'
require 'net/http'
require 'cgi'
require 'rss/maker'

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
  rss_channel = parse_feed('https://yggtorrent.is/rss?type=1&parent_category=2145')

  items = rss_channel.items.map do |item|
    torrent_url = URI(item.enclosure.url)
    torrent_query = torrent_url.query.split('&').map { |q| q.split('=') }.to_h
    torrent_id = torrent_query['torrent'].split('/').first

    {
      name: item.title,
      link: "https://#{ENV['DOMAINE']}/ygg/#{torrent_id}",
      published: item.pubDate
    }
  end

  make_feed('YggTorrent', 'YggTorrent RSS feed', 'https://yggtorrent.is/', items)
end

get '/ygg/:id' do
  login_response = Net::HTTP.post_form(URI('https://yggtorrent.is/user/login'), id: ENV['YGG_USERNAME'], pass: ENV['YGG_PASSWORD'])
  cookies = login_response.get_fields('Set-Cookie').map { |c| c.split(';').first.split('=') }.to_h

  torrent_uri = URI("https://yggtorrent.is/engine/download_torrent?id=#{params['id']}")
  torrent_response = Net::HTTP.start(torrent_uri.host, torrent_uri.port, use_ssl: torrent_uri.scheme == 'https') do |http|
    request = Net::HTTP::Get.new(torrent_uri.request_uri)
    request['Cookie'] = CGI::Cookie.new('ygg_', cookies['ygg_']).to_s

    http.request(request)
  end

  content_type 'application/x-bittorrent'
  torrent_response.body
end

get '/eztv', provides: 'rss' do
  rss_channel = parse_feed('https://eztv.ag/ezrss.xml')
  items = rss_channel.items.map do |item|
    { name: item.title, link: item.enclosure.url, published: item.pubDate }
  end

  make_feed('EZTV', 'EZTV RSS feed', 'https://eztv.ag/', items)
end
