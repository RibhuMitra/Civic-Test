-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";

-- Users table (extends Supabase auth.users)
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT UNIQUE NOT NULL,
  full_name TEXT,
  avatar_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Issues table
CREATE TABLE public.issues (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  title VARCHAR(255) NOT NULL,
  description TEXT NOT NULL,
  image_url TEXT,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  address TEXT,
  status VARCHAR(50) DEFAULT 'open', -- open, in_progress, resolved
  priority VARCHAR(20) DEFAULT 'normal', -- low, normal, high, urgent
  category VARCHAR(50), -- pothole, streetlight, garbage, etc.
  votes_count INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Votes table
CREATE TABLE public.votes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  issue_id UUID REFERENCES public.issues(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(issue_id, user_id) -- Prevent duplicate votes
);

-- User locations table
CREATE TABLE public.user_locations (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  accuracy DOUBLE PRECISION,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  is_sharing_location BOOLEAN DEFAULT TRUE
);

-- Alerts table
CREATE TABLE public.alerts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  issue_id UUID REFERENCES public.issues(id) ON DELETE CASCADE NOT NULL,
  distance_km DOUBLE PRECISION NOT NULL,
  alert_type VARCHAR(50) DEFAULT 'new_issue',
  title VARCHAR(255) NOT NULL,
  message TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  seen_at TIMESTAMP WITH TIME ZONE,
  clicked_at TIMESTAMP WITH TIME ZONE
);

-- Notification preferences
CREATE TABLE public.notification_preferences (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  alerts_enabled BOOLEAN DEFAULT TRUE,
  push_enabled BOOLEAN DEFAULT TRUE,
  email_enabled BOOLEAN DEFAULT FALSE,
  quiet_hours_start TIME,
  quiet_hours_end TIME,
  max_distance_km INTEGER DEFAULT 5,
  device_tokens JSONB DEFAULT '[]',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX idx_issues_location ON public.issues(latitude, longitude);
CREATE INDEX idx_issues_created ON public.issues(created_at DESC);
CREATE INDEX idx_issues_votes ON public.issues(votes_count DESC);
CREATE INDEX idx_votes_issue ON public.votes(issue_id);
CREATE INDEX idx_votes_user ON public.votes(user_id);
CREATE INDEX idx_user_locations_coords ON public.user_locations(latitude, longitude);
CREATE INDEX idx_alerts_user_unseen ON public.alerts(user_id, seen_at) WHERE seen_at IS NULL;

-- Function to calculate distance between two points
CREATE OR REPLACE FUNCTION calculate_distance(
  lat1 DOUBLE PRECISION,
  lon1 DOUBLE PRECISION,
  lat2 DOUBLE PRECISION,
  lon2 DOUBLE PRECISION
) RETURNS DOUBLE PRECISION AS $$
BEGIN
  RETURN 6371 * acos(
    LEAST(1,
      cos(radians(lat1)) * cos(radians(lat2)) * 
      cos(radians(lon2) - radians(lon1)) + 
      sin(radians(lat1)) * sin(radians(lat2))
    )
  );
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Function to validate and process votes
CREATE OR REPLACE FUNCTION vote_issue(
  p_issue_id UUID,
  p_user_id UUID,
  p_user_lat DOUBLE PRECISION,
  p_user_lon DOUBLE PRECISION
) RETURNS JSON AS $$
DECLARE
  v_issue_lat DOUBLE PRECISION;
  v_issue_lon DOUBLE PRECISION;
  v_distance DOUBLE PRECISION;
  v_existing_vote UUID;
BEGIN
  -- Get issue location
  SELECT latitude, longitude INTO v_issue_lat, v_issue_lon
  FROM public.issues WHERE id = p_issue_id;
  
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Issue not found');
  END IF;
  
  -- Calculate distance
  v_distance := calculate_distance(p_user_lat, p_user_lon, v_issue_lat, v_issue_lon);
  
  -- Check if within 5km
  IF v_distance > 5 THEN
    RETURN json_build_object(
      'success', false, 
      'error', 'You must be within 5km of the issue to vote',
      'distance', v_distance
    );
  END IF;
  
  -- Check for existing vote
  SELECT id INTO v_existing_vote FROM public.votes 
  WHERE issue_id = p_issue_id AND user_id = p_user_id;
  
  IF FOUND THEN
    RETURN json_build_object('success', false, 'error', 'You have already voted on this issue');
  END IF;
  
  -- Insert vote
  INSERT INTO public.votes (issue_id, user_id) VALUES (p_issue_id, p_user_id);
  
  -- Update vote count
  UPDATE public.issues SET votes_count = votes_count + 1 WHERE id = p_issue_id;
  
  RETURN json_build_object('success', true, 'message', 'Vote recorded successfully');
END;
$$ LANGUAGE plpgsql;

-- Trigger function for new issue alerts
CREATE OR REPLACE FUNCTION notify_nearby_users()
RETURNS TRIGGER AS $$
DECLARE
  user_record RECORD;
  distance_km DOUBLE PRECISION;
  alert_title TEXT;
  alert_message TEXT;
BEGIN
  alert_title := 'New Issue Nearby: ' || NEW.title;
  
  FOR user_record IN 
    SELECT ul.*, np.* 
    FROM public.user_locations ul
    JOIN public.notification_preferences np ON ul.user_id = np.user_id
    WHERE ul.is_sharing_location = TRUE 
      AND np.alerts_enabled = TRUE
      AND ul.user_id != NEW.user_id
  LOOP
    distance_km := calculate_distance(
      NEW.latitude, NEW.longitude,
      user_record.latitude, user_record.longitude
    );
    
    IF distance_km <= user_record.max_distance_km THEN
      alert_message := FORMAT('%s reported %.1f km away', NEW.title, distance_km);
      
      INSERT INTO public.alerts (
        user_id, issue_id, distance_km, alert_type, title, message
      ) VALUES (
        user_record.user_id, NEW.id, distance_km, 'new_issue', alert_title, alert_message
      );
    END IF;
  END LOOP;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for new issues
CREATE TRIGGER issue_alert_trigger
AFTER INSERT ON public.issues
FOR EACH ROW
EXECUTE FUNCTION notify_nearby_users();

-- RLS Policies
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.issues ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.votes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_preferences ENABLE ROW LEVEL SECURITY;

-- Profiles policies
CREATE POLICY "Users can view all profiles" ON public.profiles FOR SELECT USING (true);
CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- Issues policies
CREATE POLICY "Anyone can view issues" ON public.issues FOR SELECT USING (true);
CREATE POLICY "Authenticated users can create issues" ON public.issues FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own issues" ON public.issues FOR UPDATE USING (auth.uid() = user_id);

-- Votes policies
CREATE POLICY "Anyone can view votes" ON public.votes FOR SELECT USING (true);
CREATE POLICY "Authenticated users can create votes" ON public.votes FOR INSERT WITH CHECK (auth.uid() = user_id);

-- User locations policies
CREATE POLICY "Users can view own location" ON public.user_locations FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can update own location" ON public.user_locations FOR ALL USING (auth.uid() = user_id);

-- Alerts policies
CREATE POLICY "Users can view own alerts" ON public.alerts FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can update own alerts" ON public.alerts FOR UPDATE USING (auth.uid() = user_id);

-- Notification preferences policies
CREATE POLICY "Users can manage own preferences" ON public.notification_preferences FOR ALL USING (auth.uid() = user_id);