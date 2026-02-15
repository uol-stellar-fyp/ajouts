using UnityEngine;
using UnityEngine.UI;
using UnityEngine.Playables;
using UnityEngine.Timeline;
using System.Text;

/// <summary>
/// This script is responsible for displaying the current frame and total frames of a timeline in a text component during play mode.
/// </summary>
[ExecuteInEditMode]
public class HUD_frame : MonoBehaviour
{
    [Tooltip("Source timeline to retrieve timing information.")]
    [SerializeField]
    public PlayableDirector m_masterPlayable;
    private Text text;
    private StringBuilder stringBuilder;
    private float total_frames;

    /// <summary>
    /// The OnEnable method is called when the script is enabled.
    /// It initializes the Text component and calculates the total number of frames in the timeline.
    /// </summary>
    private void OnEnable()
    {
        text = gameObject.GetComponent<Text>();
        stringBuilder = new StringBuilder();

        if (m_masterPlayable != null)
        {
            TimelineAsset timeline = (TimelineAsset)m_masterPlayable.playableAsset;
            Debug.Assert(timeline != null);

            total_frames = Mathf.RoundToInt((float)timeline.editorSettings.frameRate * (float)m_masterPlayable.duration);
        }
    }

    /// <summary>
    /// The Update method is called once per frame.
    /// It updates the Text component to display the current frame and total frames of the timeline.
    /// </summary>
    void Update()
    {
        if (text != null && m_masterPlayable != null && m_masterPlayable.isActiveAndEnabled)
        {
            TimelineAsset timeline = (TimelineAsset)m_masterPlayable.playableAsset;
            Debug.Assert(timeline != null);

            var s   = (float)m_masterPlayable.time;
            var fps = (float)timeline.editorSettings.frameRate;
            int f   = Mathf.RoundToInt(fps * s);

            stringBuilder.Length = 0; // Clear the string builder
            stringBuilder.AppendFormat("{0:00}:{1:00}:{2:00} [{3}/{4}]",
                Mathf.Floor(s / 60), //minutes
                Mathf.Floor(s) % 60, //seconds
                Mathf.Floor((s * 100) % 100), //milliseconds
                f, //current frame
                total_frames); //total frames
            text.text = stringBuilder.ToString();
        }
    }
}
