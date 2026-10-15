# The signed-in user's own sessions, to review them and end the ones they do not recognize (ASVS V7.5.2).
class ActiveSessionsController < ApplicationController
  def index
    @sessions = Current.user.sessions.order(updated_at: :desc)
  end

  def destroy
    Current.user.sessions.find(params[:id]).destroy
    redirect_to active_sessions_path, notice: "Session ended."
  end
end
