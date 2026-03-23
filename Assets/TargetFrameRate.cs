using UnityEngine;

public class TargetFrameRate : MonoBehaviour
{
    // Start is called once before the first execution of Update after the MonoBehaviour is created
    void Awake()
    {
        QualitySettings.vSyncCount = 0;
        Application.targetFrameRate = 24;
        Debug.Log("vSync: " + QualitySettings.vSyncCount);
        Debug.Log("Target frame rate: " + Application.targetFrameRate);
        Debug.Log("Current frame rate: " + (1f / Time.deltaTime));
    }
    
    // Start is called once before the first execution of Update after the MonoBehaviour is created
    void Start()
    {
        QualitySettings.vSyncCount = 0;
        Application.targetFrameRate = 24;
        Debug.Log("vSync: " + QualitySettings.vSyncCount);
        Debug.Log("Target frame rate: " + Application.targetFrameRate);
        Debug.Log("Current frame rate: " + (1f / Time.deltaTime));
    }

    // Update is called once per frame
    void Update()
    {
        Debug.Log("Current frame rate: " + (1f / Time.deltaTime));
        
    }
}
