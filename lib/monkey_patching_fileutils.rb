# ref. https://github.com/docker/for-linux/issues/1015#issuecomment-811453779
module FileUtilsDockerPatch
  def copy_file(dest)
    FileUtils.touch(path())
    super
  end
end

module FileUtils
  class Entry_
    prepend FileUtilsDockerPatch
  end
end
