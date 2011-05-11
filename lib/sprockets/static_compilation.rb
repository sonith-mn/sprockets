require 'sprockets/asset_pathname'
require 'sprockets/utils'
require 'fileutils'
require 'pathname'

module Sprockets
  module StaticCompilation
    def static_root
      @static_root
    end

    def static_root=(root)
      expire_index!
      @static_root = root
    end

    def precompile(*paths)
      raise "missing static root" unless @static_root

      paths.each do |path|
        files.each do |logical_path|
          if path.is_a?(Regexp)
            next unless path.match(logical_path.to_s)
          else
            next unless logical_path.fnmatch(path.to_s)
          end

          if asset = find_asset_in_path(logical_path)
            digest_path = Utils.path_with_fingerprint(logical_path, asset.digest)
            filename = @static_root.join(digest_path)

            FileUtils.mkdir_p filename.dirname

            filename.open('w') do |f|
              f.write asset.to_s
            end
          end
        end
      end
    end

    protected
      def find_asset_in_static_root(logical_path)
        return unless static_root

        pathname = Pathname.new(static_root.join(logical_path))
        asset_pathname = AssetPathname.new(pathname, self)

        entries = entries(pathname.dirname)

        if entries.empty?
          return nil
        end

        if !Utils.path_fingerprint(pathname)
          pattern = /^#{Regexp.escape(asset_pathname.basename_without_extensions.to_s)}
                     -[0-9a-f]{7,40}
                     #{Regexp.escape(asset_pathname.extensions.join)}$/x

          entries.each do |filename|
            if filename.to_s =~ pattern
              asset = StaticAsset.new(self, pathname.dirname.join(filename))
              return asset
            end
          end
        end

        if entries.include?(pathname.basename) && pathname.file?
          asset = StaticAsset.new(self, pathname)
          return asset
        end

        nil
      end

    private
      def files
        files = Set.new
        paths.each do |base_path|
          base_pathname = Pathname.new(base_path)
          Dir["#{base_pathname}/**/*"].each do |filename|
            logical_path = Pathname.new(filename).relative_path_from(base_pathname)
            files << path_without_engine_extensions(logical_path)
          end
        end
        files
      end

      def path_without_engine_extensions(pathname)
        asset_pathname = AssetPathname.new(pathname, self)
        asset_pathname.engine_extensions.inject(pathname) do |p, ext|
          p.sub(ext, '')
        end
      end

      def entries(pathname)
        @entries[pathname.to_s] ||= pathname.entries.reject { |entry| entry.to_s =~ /^\.\.?$/ }
      rescue Errno::ENOENT
        @entries[pathname.to_s] = []
      end
  end
end