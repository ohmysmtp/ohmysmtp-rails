require 'test_helper'
require 'pry'

class OhMySMTP::Rails::Test < ActiveSupport::TestCase
  setup do
    ActionMailer::Base::delivery_method = :ohmysmtp
    ActionMailer::Base.ohmysmtp_settings = { api_token: 'api_token' }

    stub_request(:post, 'https://app.ohmysmtp.com/api/v1/send')
      .to_return(
        body: { "status": 'queued', "id": 1 }.to_json,
        headers: { content_type: 'application/json' },
        status: 200
      )

    @test_email = TestMailer.welcome_email
  end

  test 'truth' do
    assert_kind_of Module, OhMySMTP::Rails
  end

  test 'api token can be set' do
    ActionMailer::Base.ohmysmtp_settings = { api_token: 'api-token' }
    assert_equal ActionMailer::Base.ohmysmtp_settings[:api_token], 'api-token'
  end

  test 'raises ArgumentError if no api token set' do
    ActionMailer::Base.ohmysmtp_settings = { }
    assert_raise(ArgumentError) { @test_email.deliver! }
  end

  test 'raises ArgumentError if no from address in email' do
    t = TestMailer.welcome_email
    t.from = nil
    assert_raise(ArgumentError) { t.deliver! }
  end

  test 'raises ArgumentError if no to address in email' do
    t = TestMailer.welcome_email
    t.to = nil
    assert_raise(ArgumentError) { t.deliver! }
  end

  test 'send basic emails to endpoint' do
    @test_email.deliver!
  end

  test 'supports multiple attachments' do
    t = TestMailer.welcome_email
    t.attachments['logo.png'] = File.read("#{Dir.pwd}/test/logo.png")
    t.attachments['l2.png'] = File.read("#{Dir.pwd}/test/logo.png")

    t.deliver!

    assert_requested(
      :post, 'https://app.ohmysmtp.com/api/v1/send',
      times: 1
    ) do |req|
      attachments = JSON.parse(req.body)['attachments']
      attachments[0]['name'] == 'logo.png' && attachments[1]['name'] == 'l2.png'
    end
  end

  test 'supports custom mime types' do
    t = TestMailer.welcome_email
    t.attachments['logo.png'] = {
      mime_type: 'custom/type',
      content: File.read("#{Dir.pwd}/test/logo.png")
    }
    t.deliver!

    assert_requested(
      :post, 'https://app.ohmysmtp.com/api/v1/send',
      times: 1
    ) do |req|
      JSON.parse(req.body)['attachments'][0]['content_type'] == 'custom/type'
    end
  end

  # TODO: Test replyto, bcc, cc, subject, from, to etc.
end
