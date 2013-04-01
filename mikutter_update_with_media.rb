# -*- coding: utf-8 -*-

Plugin.create :update_with_media do


  command(:update_with_media,
          name: '画像付きで投稿する',
          condition: lambda{ |opt| true },
          visible: true,
          role: :postbox) do |opt|
    begin

      dialog = Gtk::FileChooserDialog.new("Select Upload Image",
                                          nil,
                                          Gtk::FileChooser::ACTION_OPEN,
                                          nil,
                                          [Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL],
                                          [Gtk::Stock::OPEN, Gtk::Dialog::RESPONSE_ACCEPT])

      filter = Gtk::FileFilter.new
      filter.name = "Image Files"
      filter.add_pattern('*.png')
      filter.add_pattern('*.PNG')
      filter.add_pattern('*.jpg')
      filter.add_pattern('*.JPG')
      filter.add_pattern('*.jpeg')
      filter.add_pattern('*.JPEG')
      filter.add_pattern('*.gif')
      filter.add_pattern('*.GIF')
      dialog.add_filter(filter)

      preview = Gtk::Image.new
      dialog.preview_widget = preview
      dialog.signal_connect("update-preview") {
        filename = dialog.preview_filename
        if filename
          unless File.directory?(filename)
            pixbuf = Gdk::Pixbuf.new(filename, 128, 128)
            preview.set_pixbuf(pixbuf)
            dialog.set_preview_widget_active(true)
          else
            dialog.set_preview_widget_active(false)
          end
        else
          dialog.set_preview_widget_active(false)
        end
      }

      if dialog.run == Gtk::Dialog::RESPONSE_ACCEPT
        filename = dialog.filename.to_s
        puts filename
      else
        filename = nil
      end
      dialog.destroy

      if filename
        message = scan_message Plugin.create(:gtk).widgetof(opt.widget)
        Thread.new {
          update_with_media(message, filename)
        }
        clear Plugin.create(:gtk).widgetof(opt.widget)
      end

    rescue Exception => e
      Plugin.call(:update, nil, [Message.new(message: e.to_s, system: true)])
    end
  end


  def scan_message(postbox)
    msg = {}
    msg[:status] = postbox.widget_post.buffer.text
    msg[:status] += UserConfig[:footer] if postbox.method(:add_footer?).()
    msg[:replyto] = postbox.method(:service).call()[:id_str] if postbox.method(:reply?).()
    msg
  end

  def clear(postbox)
    postbox.widget_post.buffer.text = ''
    postbox.destroy if postbox.method(:reply?).()
  end

  def update_with_media(msg, filename)
    boundary = 'mikku-mikkued boundary'
    body = ''
    body.concat "--#{boundary}\r\n"
    body.concat "Content-Disposition: form-data; name=\"status\";\r\n"
    body.concat "\r\n"
    body.concat "#{msg[:status]}\r\n"
    if msg[:replyto]
      body.concat "--#{boundary}\r\n"
      body.concat "Content-Disposition: form-data; name=\"in_reply_to_status_id\";\r\n\r\n#{msg[:replyto]}"
    end
    body.concat "--#{boundary}\r\n"
    body.concat "Content-Disposition: form-data; name=\"media[]\"; filename=\"#{File.basename filename}\"\r\n"
    body.concat "Content-Type: image/jpeg\r\n"
    body.concat "Content-Transfer-Encoding: binary\r\n"
    body.concat "\r\n"
    File.open(filename, 'rb') do |f|
      body.concat f.read.force_encoding "utf-8"
    end
    body.concat "\r\n"
    body.concat "--#{boundary}--\r\n"

    uri = URI.parse 'https://upload.twitter.com/1/statuses/update_with_media.json'
    https = Net::HTTP.new uri.host, uri.port
    https.use_ssl = true
    https.start do |session|
      request = Net::HTTP::Post.new uri.request_uri
      request.set_content_type "multipart/form-data; boundary=#{boundary}"
      request.body = body
      request['Content-Length'] = request.body.bytesize

      twitter = Service.primary.twitter
      consumer = OAuth::Consumer.new twitter.consumer_key, twitter.consumer_secret, :site => "https://upload.twitter.com"
      access_token = OAuth::AccessToken.new consumer, twitter.a_token, twitter.a_secret

      access_token.sign! request
      p session.request request
    end
  end

end
