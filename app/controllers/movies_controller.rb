class MoviesController < ApplicationController
  
  before_filter :find_movie, :except => :index
  admin_actions :only => :change_plot_field
  
  rescue_from 'Net::HTTPExceptions', 'Faraday::Error::ClientError' do |error|
    render 'shared/error', :status => 500, :locals => {:error => error}
  end
  
  def index
    if @query = params[:q]
      if params[:local]
        @movies = Movie.find({:title => Regexp.new(@query, 'i')}, :sort => :title).page(params[:page])
      elsif params[:netflix]
        @movies = Netflix.search(@query, :expand => %w'directors').titles
        render :netflix_search
      else
        @movies = Movie.search(@query).paginate(:page => params[:page], :per_page => 30)
        redirect_to movie_url(@movies.first) if @movies.size == 1
      end
    elsif @director = params[:director]
      @movies = Movie.find(:directors => @director).sort(:year, :desc).page(params[:page])
    else
      @movies = Movie.last_watched.to_a
    end
    
    ajax_pagination
  end
  
  def show
    @movie.ensure_extended_info unless Movies.offline?
  end
  
  def add_to_watch
    current_user.to_watch << @movie
    ajax_actions_or_back
  end
  
  def remove_from_to_watch
    current_user.to_watch.delete @movie
    ajax_actions_or_back
  end
  
  def add_watched
    current_user.watched.rate_movie @movie, params[:liked]
    ajax_actions_or_back
  end
  
  def remove_from_watched
    current_user.watched.delete @movie
    ajax_actions_or_back
  end
  
  def wikipedia
    @movie.get_wikipedia_title unless @movie.wikipedia_title
    redirect_to @movie.wikipedia_url
  end
  
  def change_plot_field
    @movie.toggle_plot_field!
    redirect_to movie_url(@movie)
  end
  
  def dups
    @duplicate_titles = Movie.find_duplicate_titles
  end
  
  protected
  
  def find_movie
    @movie = Movie.first(params[:id]) or
      render_not_found("This movie couldn't be found.")
  end
  
  private
  
  def ajax_actions_or_back
    if request.xhr?
      response.content_type = Mime::HTML
      render :partial => 'actions', :locals => {:movie => @movie}
    else
      redirect_to :back
    end
  end

end
