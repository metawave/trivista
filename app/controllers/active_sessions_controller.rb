# The signed-in user's own sessions, to review them and end the ones they do not recognize (ASVS V7.5.2).
class ActiveSessionsController < ApplicationController
  def index
    @sessions = Current.user.sessions.where.not(id: Session.expired).order(updated_at: :desc)
  end

  def destroy
    Current.user.sessions.find(params[:id]).destroy
    Rails.event.notify("trivista.session_ended", session_id: params[:id].to_i)
    redirect_to active_sessions_path, notice: "Session ended."
  end
end
