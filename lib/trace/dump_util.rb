require 'objspace'

# DumpUtil provides a dump routine and methods to process
# the dumps it creates
module DumpUtil
  module_function

  def dump(dir = Dir.pwd)
    filename = dump_filename(dir)
    Thread.new do
      ObjectSpace.trace_object_allocations_start
      GC.start
      File.open(filename, 'w') do |f|
        ObjectSpace.dump_all(output: f)
      end
    end.join
    filename
  end

  def dump_filename(path = Dir.pwd)
    File.join(
      path,
      "#{Socket.gethostname}-#{Process.pid}-#{Time.now.to_i}.heap.json"
    )
  end
end
