require 'tilt'

module Saulabs::EmbedAssets

  class Processor < Tilt::Template
    def prepare
    end

    def evaluate(context, locals, &block)
      @asset_contents = {}
      embed_assets_enabled? ? with_data_uris(context,data) : data
    end

    def embed_assets_enabled?
      Rails.application.config.assets.embed_assets
    end

    protected

    # Mapping from extension to mime-type of all embeddable assets.
    EMBED_MIME_TYPES = {
      '.png'  => 'image/png',
      '.jpg'  => 'image/jpeg',
      '.jpeg' => 'image/jpeg',
      '.gif'  => 'image/gif',
      '.tif'  => 'image/tiff',
      '.tiff' => 'image/tiff',
      '.ttf'  => 'font/truetype',
      '.otf'  => 'font/opentype',
      '.woff' => 'font/woff'
    }

    # Font extensions for which we allow embedding:
    EMBED_EXTS      = EMBED_MIME_TYPES.keys
    EMBED_FONTS     = ['.ttf', '.otf', '.woff']

    # (32k - padding) maximum length for data-uri assets (an IE8 limitation).
    MAX_IMAGE_SIZE  = 32700

    # CSS asset-embedding regexes for URL rewriting.
    EMBED_DETECTOR  = /url\(['"]?([^\s)]+\.[a-z]+)(\?\d+)?['"]?\)/
    EMBEDDABLE      = /[\A\/]embed\//
    NOT_EMBEDDABLE  = /_ie|ie\// # either _ie suffix on file or /ie/ in path

    def with_data_uris(file, css)
      css.gsub(EMBED_DETECTOR) do |url|
        asset_path = Pathname.new($1)
        real_path = absolute_path(asset_path)
        if URI.parse($1).absolute? || !embeddable?(file.logical_path, real_path)
          "url(#{$1})"
        else
          "url(\"data:#{mime_type($1)};charset=utf-8;base64,#{encoded_contents(real_path.to_s)}\")"
        end
      end
    end

    # An asset is valid for embedding if it exists, is less than 32K, and is
    # stored somewhere inside of a folder named "embed". IE does not support
    # Data-URIs larger than 32K, and you probably shouldn't be embedding assets
    # that large in any case. Because we need to check the base64 length here,
    # save it so that we don't have to compute it again later.
    def embeddable?(logical_path, real_path)
      font = EMBED_FONTS.include?(real_path.extname)
      return false unless real_path.to_s.match(EMBEDDABLE) && real_path.exist?
      return false if logical_path.to_s.match(NOT_EMBEDDABLE)
      return false unless EMBED_EXTS.include?(real_path.extname)
      return false unless font || encoded_contents(real_path).length < MAX_IMAGE_SIZE
      return true
    end

    # Return the Base64-encoded contents of an asset on a single line.
    def encoded_contents(asset_path)
      return @asset_contents[asset_path] if @asset_contents[asset_path]
      data = read_binary_file(asset_path)
      @asset_contents[asset_path] = Base64.encode64(data).gsub(/\n/, '')
    end

    def absolute_path(asset_pathname)
      Pathname.new(File.join(Rails.public_path, asset_pathname))
    end

    # Grab the mime-type of an asset, by filename.
    def mime_type(asset_path)
      EMBED_MIME_TYPES[File.extname(asset_path)]
    end

    # `File.read`, but in "binary" mode.
    def read_binary_file(path)
      File.open(path, 'rb') {|f| f.read }
    end

  end
end

