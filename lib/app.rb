require 'sinatra/shopify-sinatra-app'
require 'nokogiri'
require 'byebug'

class SinatraApp < Sinatra::Base
  register Sinatra::Shopify

  # set the scope that your app needs, read more here:
  # http://docs.shopify.com/api/tutorials/oauth
  set :scope, 'write_themes'

  # Main App Page
  get '/' do
    shopify_session do
      heading_text = ""
      link_text = ""
      link_address = ""

      begin
        snippet = ShopifyAPI::Asset.find('snippets/notice-bar.liquid')
        doc = Nokogiri::HTML::Document.parse snippet.value
        bar = doc.xpath("//p[@id='notice-bar-content']").first

        heading_text = bar.children[0].text
        link_text = bar.children[1].text
        link_address = bar.children[1]['href']
      rescue ActiveResource::ResourceNotFound => e
      end

      erb :home, locals: {
        heading_text: heading_text,
        link_text: link_text,
        link_address: link_address
      }
    end
  end

  post '/edit' do
    shopify_session do
      heading_text = params["heading_text"]
      link_text = params["link_text"]
      link_address = params["link_address"]

      theme = ShopifyAPI::Asset.find('layout/theme.liquid')

      # inject the include for the snippet into the theme if it is not already there
      unless theme.value.include? "{% include 'notice-bar' %}"
        body_pos = theme.value.index("<body")
        body_end = theme.value.index(">", body_pos)
        theme.value.insert(body_end+1, "\n {% include 'notice-bar' %} \n")
        theme.save
      end

      # add or update the snippet
      value = erb :notice_bar, :layout => false, locals: {
        heading_text: heading_text,
        link_text: link_text,
        link_address: link_address
      }

      snippet = ShopifyAPI::Asset.new(
        key: 'snippets/notice-bar.liquid',
        value: value
      )
      snippet.save

      flash[:notice] = "Notice Bar Updated!"
      redirect '/'
    end
  end

  # this endpoint recieves the uninstall webhook
  # and cleans up data, add to this endpoint as your app
  # stores more data.
  post '/uninstall' do
    webhook_session do |params|
      current_shop.destroy
    end
  end

  private

  # This method gets called when your app is installed.
  # setup any webhooks or services you need on Shopify
  # inside here.
  def install
    shopify_session do
      # create an uninstall webhook, this webhook gets sent
      # when your app is uninstalled from a shop. It is good
      # practice to clean up any data from a shop when they
      # uninstall your app.
      uninstall_webhook = ShopifyAPI::Webhook.new({
        topic: "app/uninstalled",
        address: "#{base_url}/uninstall",
        format: "json"
      })
      uninstall_webhook.save
    end

    redirect '/'
  end

end
