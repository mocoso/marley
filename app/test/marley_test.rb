# You will need to have the rack-test gem to run these tests
#
#   gem install rack-test

require 'rubygems'
require 'sinatra'

# Set test environment
set :environment, :test

# Require application file
require '../marley'

# Require testing classes
require 'test/unit'
require 'rack/test'

require 'base64'

# "Stub" anti-spam library
class Akismetor
  def self.spam?(attributes)
    rand > 0.5 ? true : false
  end
end

class MarleyTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def test_should_show_index_page
    get '/'
    assert_equal 200, last_response.status
  end

  def test_should_show_article_page
    get '/test-article-one.html'
    # p last_response.body
    assert_equal 200, last_response.status
    assert last_response.body =~ Regexp.new(
           Regexp.escape("<h1>\n    This is the test article one\n    <span class=\"meta\">\n      23|12|2050") ),
           "HTML should contain valid <h1> title for post"
  end

  def test_should_not_find_article_by_partial_regexp_match_and_return_404
    get '/test-article.html'
    assert_equal 404, last_response.status
  end

  def test_should_send_404
    get '/test-article-three-does-no-exist.html'
    assert_equal 404, last_response.status
  end

  def test_should_create_comment
    comment_count = Marley::Comment.count
    post '/test-article-one/comments', default_comment_attributes
    assert_equal 302, last_response.status
    assert Marley::Comment.count == comment_count + 1
  end

  def test_should_not_create_commit_when_author_field_is_missing
    comment_count = Marley::Comment.count
    post '/test-article-one/comments', default_comment_attributes.merge( :author => nil )
    assert_equal 200, last_response.status
    assert Marley::Comment.count == comment_count
  end

  def test_should_fix_url_on_comment_create
    post '/test-article-one/comments', default_comment_attributes.merge(:url => 'www.example.com')
    assert_equal 'http://www.example.com', Marley::Comment.last.url
  end

  def test_should_NOT_fix_blank_url_on_comment_create
    comment_count = Marley::Comment.count
    post '/test-article-one/comments', default_comment_attributes.merge(:url => '')
    assert_equal '', Marley::Comment.last.url
  end

  def test_should_show_feed_for_index
    get '/feed'
    assert_equal 200, last_response.status
  end

  def test_should_show_feed_for_article
    get '/test-article-one/feed'
    assert_equal 200, last_response.status
  end

  def test_should_show_feed_for_combined_comments
    get '/feed/comments'
    assert_equal 200, last_response.status
  end

  def test_articles_should_have_proper_published_on_dates
    get '/'
    # p last_response.body
    assert_equal 200, last_response.status
    assert last_response.body =~ Regexp.new(Regexp.escape("<small>23|12|2050 &mdash;</small>")),
                             "HTML should contain proper date for post one"
    assert last_response.body =~ Regexp.new(Regexp.escape("<small>#{File.mtime(File.expand_path('./fixtures/002-test-article-two/')).strftime('%d|%m|%Y')} &mdash;</small>")),
                             "HTML should contain proper date for post two"
  end

  def test_admin_without_authentication
    get '/admin/test-article-one.html'
    assert_equal 401, last_response.status
  end

  def test_admin_with_bad_credentials
    get '/admin/test-article-one.html', {}, {'HTTP_AUTHORIZATION' => encode_credentials('go', 'away')}
    assert_equal 401, last_response.status
  end

  def test_admin_with_proper_credentials
    get '/admin/test-article-one.html', {}, admin_credentials
    assert_equal 200, last_response.status
  end

  def test_deleting_spam_comments
    @spam_comment = Marley::Comment.create( default_comment_attributes.merge(:author => 'spammer', :body => 'viagra-test-123') )
    delete '/admin/test-article-one/spam', { :spam_comment_ids => @spam_comment.id }, admin_credentials
  end

  private

  def default_comment_attributes
    { :ip => "127.0.0.1",
      :user_agent => "Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_5_4; en-us)",
      :body => "Testing comments...",
      :post_id => "test-article",
      :url => "www.example.com",
      :author => 'Tester',
      :email => "tester@localhost" }
  end

  def encode_credentials(username, password)
    "Basic " + Base64.encode64("#{username}:#{password}")
  end

  def admin_credentials
    {'HTTP_AUTHORIZATION'=> encode_credentials(Marley::Configuration.admin.username, Marley::Configuration.admin.password)}
  end

end
