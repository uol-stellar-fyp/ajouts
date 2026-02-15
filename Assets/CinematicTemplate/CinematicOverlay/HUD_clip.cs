using System;
using UnityEngine;
using UnityEngine.UI;
using UnityEngine.Playables;
using UnityEngine.Timeline;
using System.Text;

/// <summary>
/// This script is responsible for displaying the current clip name in a text component during play mode.
/// </summary>
[ExecuteInEditMode]
public class HUD_clip : MonoBehaviour
{
    [Tooltip("Source timeline to retrieve current clip information.")]
    [SerializeField]
    public PlayableDirector m_masterPlayable;

    [Tooltip("Name of the track you want to retrieve the current clip from (eg: Cinemachine Track).")]
    [SerializeField]
    public string m_targetTrackName;

    [Tooltip("Text added before the name of the current clip playing in the targeted track (eg: title of your content).")]
    [SerializeField]
    public string m_prefix;
    
    private Text textComponent;
    
    /// <summary>
    /// The OnEnable method is called when the script is enabled.
    /// It initializes the Text component.
    /// </summary>
    private void OnEnable()
    {
        textComponent = gameObject.GetComponent<Text>();
    }

    /// <summary>
    /// The Update method is called once per frame.
    /// It updates the Text component to display the current clip and cinematic hierarchy names.
    /// </summary>
    void Update()
    {
        if (textComponent != null)
        {
            textComponent.text = m_prefix;
            AddCurrentClipName();
        }
    }
    
    /// <summary>
    /// Adds the name of the current clip playing in the targeted track to the Text component.
    /// </summary>
    private void AddCurrentClipName()
    {
        if (m_masterPlayable == null || !m_masterPlayable.isActiveAndEnabled)
            return;

        float s = (float)m_masterPlayable.time;

        TimelineAsset timeline = (TimelineAsset)m_masterPlayable.playableAsset;

        var tracks = timeline.GetOutputTracks();
        foreach (TrackAsset track in tracks)
        {
            if (track.name.Equals(m_targetTrackName))
            {
                var clips = track.GetClips();
                foreach (TimelineClip clip in clips)
                {
                    float t0 = (float)clip.start;
                    float t1 = (float)clip.end;

                    if (t0 <= s && s < t1)
                    {
                        textComponent.text += clip.displayName;
                        break;
                    }
                }
                break;
            }
        }
    }
}
