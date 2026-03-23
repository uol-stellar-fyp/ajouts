using System.Collections;
using UnityEngine;
using UnityEngine.Playables;

public class StartupFrameRateSpikeFix : MonoBehaviour
{
    // Start is called once before the first execution of Update after the MonoBehaviour is created
    IEnumerator Start()
    {
        QualitySettings.vSyncCount = 0;
        Application.targetFrameRate = 24;
    
        // Wait for 10 frames before starting the Timeline
        for (int i = 0; i < 10; i++)
        {
            yield return null;
        }
    
        GetComponent<PlayableDirector>().Play();
    }

    // Update is called once per frame
    void Update()
    {
        
    }
}
