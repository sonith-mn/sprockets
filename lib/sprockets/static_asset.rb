require 'sprockets/asset_pathname'
require 'sprockets/utils'
require 'digest/md5'
require 'time'

module Sprockets
  class StaticAsset
    attr_reader :pathname, :content_type, :mtime, :length, :digest

    def initialize(environment, pathname)
      @pathname = Pathname.new(pathname)

      asset_pathname = AssetPathname.new(pathname, environment.engines)
      @content_type  = asset_pathname.content_type

      @mtime  = @pathname.mtime
      @length = @pathname.size

      if digest = Utils.path_fingerprint(@pathname)
        @digest = digest
      else
        @digest = Digest::MD5.hexdigest(pathname.read)
      end
    end

    def stale?
      mtime < pathname.mtime
    rescue Errno::ENOENT
      true
    end

    def each
      yield pathname.read
    end

    def to_path
      pathname.to_s
    end

    def to_s
      pathname.read
    end

    def eql?(other)
      other.class == self.class &&
        other.pathname == self.pathname &&
        other.mtime == self.mtime &&
        other.digest == self.digest
    end
    alias_method :==, :eql?
  end
end
