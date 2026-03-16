# MagRay: Intent-Aware Selection in Dense AR Scenes
## CS 8395 (Augmented Reality) - Rana Dubauskas

## Project Goal

This project introduces MagRay, an intent-aware ray-based selection technique for dense augmented reality environments. MagRay improves upon traditional straight selection rays with a "magnetic ray" that bends towards the likely target based on user intent and scene context. The system estimates user intent using hand kinematics, local scene density, and temporal locking. The magnetic attraction toward an object is adjusted in real time, allowing users to more easily select small targets in cluttered environments. Additionally, MagRay uses a temporal confirmation lock that freeze the selection during the final confirmation gesture to limit the Heisenberg effect.  

Accurate selection of targets in dense, cluttered AR scenes is a major challenge. Previous techniques of traditional ray-casting relies on high pointing precision and fails when many targets overlap in depth or there is a small movement from hand jitter. This problem is very critical in domains such as medical training, industrial maintenance, and accessibility scenarios where selecting the correct tiny target can have significant consequences. Prior work has improved AR target aquisition through approaches like target expansion, progressive refinement, adaptive control-to-display gain, and confirmation corrections. However, these appraoches address individual sources of error in isolation. MagRay introduces a unified, intent-aware selection technique that simultaneously considers scene density, user motion, and confirmation stability by dynamically bending the selection ray toward likely target while also stabilizing selection during confirmation. By integrating these signals into a single system, MagRay improves to imprive selection accuracy in dense AR environments while preserving speed and simplicity in ray-based interactions.

## Technical Approach

MagRay will be implemented as a mobile AR selection technique on iOS using Swift, SwiftUI, ARKit, RealityKit, and Core Motion. Instead of a headset-based hand ray, the system will use a screen-space-to-world-space ray cast from the center of the iPhone screen (or a tap location) into the AR scene. 

### Core Technologies
- **ARKit (ARWorldTrackingConfiguration)**
  - Provides 6DoF tracking of the iPhone pose relative to the environment.
  - Used to continuously estimate the camera position and orientation.
- **RealityKit**
  - Handles 3D scene rendering and entity management.
  - Used to create and render **ModelEntity** spheres that represent selectable targets.
- **CoreMotion**
  - Provides processed device motion data (`CMDeviceMotion`).
  - Used to create and render **ModelEntity** spheres that represent selectable targets.
- **SwiftUI + ARView**
  - Hosts the AR interface and handles gesture input (tap confirmation).

### Scene Setup
- An **AnchorEntity** will be placed in front of the camera.
- A dense cluster of small **ModelEntity spheres** will be generated around the anchor to create a cluttered selection environment.
- Each sphere will store its world position and a temporary magnetic score used by the selection algorithm.

### Ray Generation (Screen → World)
- A ray will be generated in each frame using: `arView.ray(through: screenPoint)`
- The screen point will normally be the center of the screen, functioning as an aiming reticle.
- The ray origin and direction will be used to evaluate candidate targets.

### Magenetic Target Selection
Instead of relying on RealityKit’s built-in hit test, MagRay computes a **custom score for each target.**

For each sphere:
- Compute the **shortest distance from the ray to the sphere center**
- Convert distance into a **proximity score((
- Optionally apply a **depth weighting**
```bash
score = proximity_weight * (1 / ray_distance)
      + depth_weight * depth_bias
```
The sphere with the highest score becomes the **current candidate target**.


### Motion-Aware Assistance
Magnetic snap strength will adapt based on device movement.

Using **Core Motion:**
- Compute motion magnitude from: **rotation rate** and **user acceleration**
- Behavior:
  - Phone moving fast → weaker magnetic snap
  - Phone steady → stronger magnetic snap

This allows the system to distinguish between navigation motion and careful aiming.

### Temporal Confirmation Lock

Selection confirmation occurs with a **screen tap.**

To reduce disturbances caused by touching the phone:

- Maintain a short **rolling buffer (~80–120 ms)** of recent best targets.
- When the user taps, the system selects the most stable candidate from the recent buffer, rather than the instantaneous frame.

This reduces errors caused by device movement during the tap.

### Interaction Loop
1. ARKit updates device pose.
2. Core Motion updates device motion.
3. A world-space ray is generated from the screen center.
4. The algorithm evaluates all sphere candidates.
5. The highest-scoring target is highlighted.
6. The candidate is added to a short temporal history.
7. User taps for selection
8. The system selects the most stable candidate from the recent history.

### System Architecture
```bash
iPhone Camera + AR Session
        │
        ▼
ARKit World Tracking
        │
        ▼
Ray Generation (arView.ray)
        │
        ▼
Candidate Evaluation
(ray → sphere distance)
        │
        ▼
Magnetic Scoring
(proximity + depth)
        │
        ▼
Motion Scaling (Core Motion)
        │
        ▼
Temporal Buffer (~100 ms)
        │
        ▼
Tap Confirmation
        │
        ▼
Final Target Selection
```
### Environment Profile Summary:
- Platform: iOS Mobile Augmented Reality
- SDK / Tool: Apple ARKit + RealityKit
- SDK Version: iOS 26.2 SDK (ARKit + RealityKit included in Xcode)
- Host OS: macOS 15.6 (24G84)
- IDE: Xcode 26.2
- Target OS: iOS 26.2
- Language / UI: Swift + SwiftUI

**AR Frameworks:**
- ARKit (world tracking, camera pose estimation)
- RealityKit (scene graph, rendering, ModelEntity objects)

**Motion Framework:**
- Core Motion (CMDeviceMotion for rotation rate and user acceleration)

**Target Hardware:** 
iPhone 15 Plus

## Novelty and Contribution

MagRay is a systems integration and modification of existing AR selection techniques. 

Prior work in AR selection has explored techniques such as:
- **Target expansion** (e.g., Bubble Cursor / Bubble Ray) to enlarge effective target size
- **Progressive refinement** (e.g., Depth Ray, SQUAD) to resolve clutter through multi-step selection
- **Adaptive control-to-display gain** to improve precision during slow movement
- **Confirmation-aware methods** to correct errors caused by the click or pinch gesture

However, these techniques typically address one source of error at a time. Additionally, most are designed for headset-based VR/AR systems using hand rays or controllers.

MagRay is an integration of these ideas adapted for mobile AR. The system combines three previously separate mechanisms into a single intent-aware selection pipeline:
- **Magnetic proximity scoring** to expand the effective selection region of nearby objects
- **Motion-aware assistance** using device motion to infer whether the user is navigating or precisely aiming
- **Temporal confirmation** locking to reduce selection errors caused by the tap gesture

Aditionally, MagRay explores these ideas under a screen-space-to-world-space mobile AR interaction model, where the selection ray originates from the phone camera rather than a tracked hand.

**Contribution Summary:**
- A **mobile AR implementation** of an intent-aware magnetic selection technique
- A **unified selection pipeline** integrating proximity scoring, motion-aware assistance, and temporal confirmation stabilization
- An evaluation of whether this integration improves target selection accuracy in **dense AR** scenes

## Evaluation Plan
To evaluate whether MagRay improves target selection in dense AR scenes, I will conduct a  target acquisition experiment comparing MagRay against a baseline ray-casting technique.

### Experimental Variables

**Interaction Techniques:**
1. Baseline Ray Casting: Uses standard screen-space ray casting (object intersected by the ray is selected directly with no magnetic assistance or temporal stabilization)
2. MagRay: magnetic scoring + motion scaling + temporal lockin

**Density Conditions:**
To evaluate performance in cluttered environments, the number of targets will vary:
- **Low Density:** ~10 objects
- **Medium Density:** ~30 objects
- **High Density:** ~60 objects

Objects will be placed close together so that multiple targets lie near the ray direction.

### Setup

**10 participants** will be asked to select a highlighted target sphere among 10-20 spheres in the AR scene

**Trials:**

We will perform 12 trials per density per interaction technique. Therefore, we will have a total of 3 (densities) * 2 (interaction techiques) * 12 trials = **72 total trials**.

### Metrics
The system will automatically log:
- **Selection Accuracy:** Percentage of correct targets selected
- **Selection Time:** Time from target appearance to confirmation in ms
- **Error Rate:** Percentage of incorrect selections
- **Ray Stability:** Number of times the best candidate changes (candidate-switch count)

### Success Criteria

MagRay will be considered successful if it meets the following conditions when compared to baseline ray casting:
- **Lower error rate:** MagRay reduces incorrect selections by at least **15–20%** in medium and high density scenes.
- **Comparable or improved selection time:** Average selection time remains **within ±10% of the baseline** or becomes faster.
- **Higher accuracy in dense scenes:** In the high-density condition, MagRay achieves at least a 10% higher target selection accuracy than baseline ray casting.
- **Improved ray stability:** The average **candidate-switch count** in the 80–120 ms window before confirmation is lower than the baseline

## Milestones and Contingencies

### Minimal Viable Demo (MVD)
The minimum viable version of MagRay will include:
- An ARKit + RealityKit scene running on iPhone
- Adense cluster of selectable sphere targets
- A ray generated from the center of the screen
- A custom magnetic scoring function selecting the closest target to the ray

### Development Milestones

**Milestone 1 – AR Scene Setup**
- Initialize ARKit session using ARWorldTrackingConfiguration
- Create RealityKit scene with AnchorEntity
- Spawn dense cluster of ModelEntity spheres

**Milestone 2 – Ray Generation**
- Implement screen-space ray generation using arView.ray(through:)
- Visualize aiming reticle and highlight intersected sphere

**Milestone 3 – Magnetic Selection Algorithm**
- Compute ray-to-sphere distances
- Implement proximity-based magnetic scoring
- Highlight current best candidate

**Milestone 4 – Motion-Aware Scaling**
- Integrate Core Motion (CMDeviceMotion)
- Scale magnetic snap strength based on device movement

**Milestone 5 – Temporal Locking**
- Implement short history buffer of recent candidate targets
- Select most stable candidate at tap confirmation

**Milestone 6 – Evaluation Experiment**
- Implement experiment mode with randomized target selection
- Log selection accuracy and time
- Run evaluation trials and analyze results

### Hardest Technical Challenges
The most challenging components are likely:
- Computing **stable ray-to-object** scoring in a cluttered scene
- Preventing **rapid flickering between candidate targets**
- Balancing magnetic snap strength so it **assists but does not override user intent**

### Contingency Plan
If the full MagRay system proves too complex we will try one of the following simpler versions:
1. Implement magnetic proximity scoring only (no motion scaling).
2. Implement temporal confirmation locking only to stabilize selections.
3. Evaluate ray proximity snapping vs baseline ray casting without motion-based adaptation.
