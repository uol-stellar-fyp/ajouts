using UnityEngine;
using UnityEngine.Scripting;

public class SkyBoxControllerScript : MonoBehaviour
{
    [SerializeField] private Material[] skyboxMaterialOptions;
    
    // Start is called once before the first execution of Update after the MonoBehaviour is created
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        
    }
    [Preserve]
    public void UpdateSkybox(int index)
    {
        RenderSettings.skybox = skyboxMaterialOptions[index];
        DynamicGI.UpdateEnvironment();
    }
    
    [Preserve]
    public static void UpdateSkybox2StarField()
    {
        RenderSettings.skybox = Renderer.FindObjectsByType<Material>(FindObjectsSortMode.InstanceID)[0];
        DynamicGI.UpdateEnvironment();
    }
    
    [Preserve]
    public static void UpdateSkybox2Sky()
    {
        RenderSettings.skybox = Renderer.FindObjectsByType<Material>(FindObjectsSortMode.InstanceID)[1];
        DynamicGI.UpdateEnvironment();
    }
}
