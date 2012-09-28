require File.expand_path("../helper", __FILE__)

module Sawyer
  class AgentTest < TestCase
    def setup
      @stubs = Faraday::Adapter::Test::Stubs.new
      @agent = Sawyer::Agent.new "http://foo.com/a/" do |conn|
        conn.builder.handlers.delete(Faraday::Adapter::NetHttp)
        conn.adapter :test, @stubs
      end
    end

    def test_accesses_root_relations
      @stubs.get '/a/' do |env|
        assert_equal 'foo.com', env[:url].host

        [200, {}, Sawyer::Agent.encode(
          :_links => {
            :users => {:href => '/users'}})]
      end

      assert_equal 200, @agent.root.status

      assert_equal '/users', @agent.rels[:users].href
      assert_equal :get,     @agent.rels[:users].method
    end

    def test_saves_root_endpoint
      @stubs.get '/a/' do |env|
        [200, {}, '{}']
      end

      assert_kind_of Sawyer::Response, @agent.root
      assert_not_equal @agent.root.time, @agent.start.time
    end

    def test_starts_a_session
      @stubs.get '/a/' do |env|
        assert_equal 'foo.com', env[:url].host

        [200, {}, Sawyer::Agent.encode(
          :_links => {
            :users => {:href => '/users'}})]
      end

      res = @agent.start

      assert_equal 200, res.status
      assert_kind_of Sawyer::Resource, resource = res.data

      assert_equal '/users', resource.rels[:users].href
      assert_equal :get,     resource.rels[:users].method
    end

    def test_requests_with_body_and_options
      @stubs.post '/a/b/c' do |env|
        assert_equal '{"a":1}', env[:body]
        assert_equal 'abc',     env[:request_headers]['x-test']
        assert_equal 'foo=bar', env[:url].query
        [200, {}, "{}"]
      end

      res = @agent.call :post, 'b/c' , {:a => 1},
        :headers => {"X-Test" => "abc"},
        :query   => {:foo => 'bar'}
      assert_equal 200, res.status
    end

    def test_requests_with_body_and_options_to_get
      @stubs.get '/a/b/c' do |env|
        assert_nil env[:body]
        assert_equal 'abc',     env[:request_headers]['x-test']
        assert_equal 'foo=bar', env[:url].query
        [200, {}, "{}"]
      end

      res = @agent.call :get, 'b/c' , {:a => 1},
        :headers => {"X-Test" => "abc"},
        :query   => {:foo => 'bar'}
      assert_equal 200, res.status
    end

    def test_encodes_and_decodes_times
      time = Time.at(Time.now.to_i)
      data = {:a => 1, :b => true, :c => 'c', :created_at => time}
      data = [data.merge(:foo => [data])]
      encoded = Sawyer::Agent.encode(data)
      decoded = Sawyer::Agent.decode(encoded)

      2.times do
        assert_equal 1, decoded.size
        decoded = decoded.shift

        assert_equal 1, decoded[:a]
        assert_equal true, decoded[:b]
        assert_equal 'c', decoded[:c]
        assert_equal time, decoded[:created_at]
        decoded = decoded[:foo]
      end
    end
  end
end

