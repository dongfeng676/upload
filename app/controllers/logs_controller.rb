class LogsController < ApplicationController
  protect_from_forgery :except => :upload
  def index
    render 'logs/upload'
  end
  def upload
    UploadUtil.logstash(params[:file])
    render json:{info:"success"}
  end
end
