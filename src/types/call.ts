export interface Call {
  id: string;
  chatId: string;
  callerId: string;
  type: 'audio' | 'video';
  status: 'initiated' | 'ringing' | 'answered' | 'ended' | 'missed' | 'declined' | 'busy';
  startedAt: Date;
  endedAt?: Date;
  duration?: number;
  metadata?: Record<string, any>;
}

export interface CallParticipant {
  id: string;
  callId: string;
  userId: string;
  joinedAt?: Date;
  leftAt?: Date;
  status: 'invited' | 'ringing' | 'joined' | 'left' | 'declined';
}

export interface CallSignalData {
  type: 'offer' | 'answer' | 'ice-candidate' | 'end' | 'decline' | 'busy';
  callId: string;
  from: string;
  to: string;
  payload: any;
}

export interface WebRTCConfig {
  iceServers: RTCIceServer[];
}