# coding: utf-8
module UploadUtil
  class << self
    RedisServerIp = "221.228.88.99"

    def logstash(file)
      begin
        #处理上传，得到上传后的路径，和文件名称
        upload_file_path,upload_file_name = upload(file)

        #处理压缩,extract_name是不包含后缀的名称
        extract_dir,extract_name = handle_extract(upload_file_path,upload_file_name)

        #得到真正解压后路径
        extract_path = get_really_path(extract_dir)

        #生成logstash配置文件
        logstash_conf_path = generate_logstash_conf(extract_path,extract_name)

        #重启logstash服务器
        #logstash_restart
      rescue Exception => e
        AppLog.info(e.message)
        AppLog.info(e.backtrace.inspect)
      end
    end

    def upload(file)
      begin
        #创建上传路径
        dir_path = Rails.root.join("public","user_log")
        FileUtils.mkdir_p(dir_path) unless Dir.exist?(dir_path)

        #源文件名字
        file_name = file.original_filename
        #存储路径
        file_path = dir_path + file_name
        #上传文件
        File.open(file_path,"wb") do |f|
          f.write(file.read)
        end
      rescue Exception => e
        AppLog.info(e.message)
        AppLog.info(e.backtrace.inspect)
      end
      return [file_path,file_name]
    end

    def handle_extract(file_path,file_name)
      begin
        #解压目录　(后来要将用户标示加上，否则无法分别是那个用户日志)
        extract_path = Rails.root.join("public","extract",Time.now.strftime("%Y-%m-%d_%H:%m:%S"))
        FileUtils.mkdir_p(extract_path) unless Dir.exist?(extract_path)

        #logstash真正要解析的路径
        really_path = extract_path
        really_name = ""
        if /.*\.tar\.gz$/.match(file_name)

          `tar xzvf #{file_path} -C #{extract_path}`
          really_path = get_really_path(extract_path)
          really_name = file_name.gsub(".tar.gz","")

        elsif /.*\.zip$/.match(file_name)

          `unzip #{file_path} -d #{extract_path}`
          really_path = get_really_path(extract_path)
          really_name = file_name.gsub(".zip","")

        elsif /.*\.log/.match(file_name)
          really_path = file_path
          really_name = file_name
          `rm -rf #{extract_path}`
        end
      rescue Exception =>e
        AppLog.info(e.message)
        AppLog.info(e.backtrace.inspect)
      end
      return [really_path,really_name]
    end

    def get_really_path(extract_path)
      really_path = ""
      begin
        dir_file_names = `ls #{extract_path}`
        if dir_file_names.first.present?
          really_path = extract_path + dir_file_names.first
        else
          raise "解压后文件不存在"
        end
      rescue Exception => e  
        AppLog.info(e.message)
        AppLog.info(e.backtrace.inspect)
      end
      return really_path
    end

    def generate_logstash_conf(really_path,really_name)
      #生成配置文件内容
      input_str = "
        input {
          file {
            path => really_path_example
            start_position => 'beginning'
          }
        }
      "
      input_str = input_str.gsub("really_path_example",really_path)
      output_str = "
        redis {
          data_type => 'list'
          key => 'yesqin_list_upload'
          host => '#{RedisServerIp}'
          port => 6379
        }
      "
      logstash_str = input_str + output_str

      #存储配置文件
      logstash_dir = Rails.root.join("public","upload_logstash")
      FileUtils.mkdir_p(logstash_dir) unless Dir.exist?(logstash_dir)
      logstash_path = logstash_dir + really_name + ".conf"

      File.open(logstash_path,"wb") do |f|
        f.write(logstash_str)
      end
      return logstash_path
    end

    def logstash_restart
      begin
        #如果语法正确就重启logstash服务
        configtest = `service logstash configtest`
        if configtest_flag.include?("Configuration OK")
          `service logstash restart`
        else
          raise "配置文件语法错误"
        end
      rescue Exception => e
        AppLog.info(e.message)
        AppLog.info(e.backtrace.inspect)
      end
    end
  end
end