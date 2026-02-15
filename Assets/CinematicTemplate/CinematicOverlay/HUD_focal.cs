using System;
using UnityEngine;
using UnityEngine.UI;
using System.Text;

/// <summary>
/// This script is responsible for displaying the current focal length and aperture of a camera in a text component during play mode.
/// </summary>
[ExecuteInEditMode]
public class HUD_focal : MonoBehaviour
{
    [Tooltip("Target camera to retrieve physical data from.")]
    public Camera HDRPCamera;

    private Text textComponent;
    private StringBuilder stringBuilder;
    private Camera targetCamera;

    /// <summary>
    /// The OnEnable method is called when the script is enabled.
    /// It initializes the StringBuilder.
    /// </summary>
    private void OnEnable()
    {
        textComponent = gameObject.GetComponent<Text>();
        targetCamera = HDRPCamera != null ? HDRPCamera : Camera.main;
        stringBuilder = new StringBuilder();
    }

    /// <summary>
    /// The Update method is called once per frame.
    /// It updates the Text component to display the focal length and aperture of the target Camera.
    /// </summary>
    void Update()
    {
        if (targetCamera == null)
            return;

        if (textComponent != null)
        {
            stringBuilder.Length = 0; // Clear the string builder

            stringBuilder.AppendFormat("{0:0.00} mm - f/{1:0.00}",targetCamera.focalLength, targetCamera.aperture);
            textComponent.text = stringBuilder.ToString();
        }
    }
}
