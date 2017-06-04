class SongsController < ApplicationController

  before_action :require_edit_privileges, only: [:new, :create, :edit, :update]
  before_action :require_delete_privileges, only: [:destroy] # implement destroy later

  SONGS_PER_PAGE_DEFAULT = 10

  def index
    respond_to do |format|
      format.json do
        if params[:search][:value].present?
          songs = Song.search_by_keywords(params[:search][:value])
        else
          # if no search terms, show songs alphabetically
          songs = Song.order(name: :asc)
        end

        songs = songs.where(key: params[:key]) if params[:key].present?
        songs = songs.where(tempo: params[:tempo]) if params[:tempo].present?
        songs = songs.select('id, artist, tempo, key, name, chord_sheet')
        recordsFiltered = songs.length

        if params[:start].present?
          page_size = (params[:length] || SONGS_PER_PAGE_DEFAULT).to_i
          page_num = (params[:start].to_i / page_size.to_i) + 1

          songs = songs.paginate(page: page_num, per_page: page_size)
        end

        song_data = {
          draw: params[:draw].to_i,
          recordsTotal: Song.count,
          recordsFiltered: recordsFiltered,
          data: songs
        }

        render json: song_data and return
      end

      format.html do
        return
      end
    end
  end

  def show
    @song = Song.find(params[:id])
    if params[:new_key].present?
      Transposer.transpose_song(@song, params[:new_key])
    elsif params[:numbers]
      Formatter.format_song_nashville(@song)
    end

    respond_to do |format|
      format.html do
      end
      format.json do
        render json: @song
      end
    end
  end

  def new
    @song = Song.new
  end

  def create
    @song = Song.new(song_params)
    if @song.save
      flash[:success] = "#{@song.name} successfully created!"
      logger.info "New song created: #{current_user} created #{@song}"
      redirect_to @song
    else
      render :new
    end
  end

  def edit
    @song = Song.find(params[:id])
  end

  def update
    @song = Song.find(params[:id])
    if @song.update_attributes(song_params)
      flash[:success] = "#{@song.name} successfully updated!"
      logger.info "Song updated: #{current_user} updated #{@song}"
      redirect_to @song
    else
      render :edit
    end
  end

  def print
    @song = Song.find(params[:id])
    if params[:new_key].present?
      Transposer.transpose_song(@song, params[:new_key])
    elsif params[:numbers]
      Formatter.format_song_nashville(@song)
    end
    render layout: false
  end

  private
  def song_params
    params.require(:song).permit(:name, :key, :artist, :tempo, :standard_scan, :chord_sheet)
  end
end
