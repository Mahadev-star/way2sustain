import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    const Color brandGreen = Color(0xFF43A047);
    const Color backgroundColor = Color(0xFF151717);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: backgroundColor,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 1.5,
                    colors: [Color(0xFF0A3D0A), Color(0xFF151717)],
                    stops: [0.0, 0.7],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: brandGreen, width: 3),
                          color: Colors.grey[900],
                        ),
                        child: const Icon(
                          Icons.eco,
                          size: 50,
                          color: brandGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Text(
                      'Way2Sustain',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Center(
                    child: Text(
                      'AI-Based Sustainable Travel Route Planner',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildSectionTitle('About the App'),
                  const SizedBox(height: 12),
                  _buildContentCard(
                    content:
                        'Way2Sustain is an intelligent, eco-friendly travel route planning application designed to promote sustainable mobility and reduce carbon emissions.\n\nThe app uses advanced AI techniques such as Ant Colony Optimization (ACO) to analyze real-time traffic, distance, emissions, and air quality data to recommend the most sustainable travel routes.',
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Route Comparison'),
                  const SizedBox(height: 12),
                  _buildRouteTypeCard(
                    icon: Icons.eco,
                    title: 'Eco Route',
                    description: 'Maximum sustainability focus',
                    color: brandGreen,
                  ),
                  const SizedBox(height: 8),
                  _buildRouteTypeCard(
                    icon: Icons.balance,
                    title: 'Balanced Route',
                    description: 'Equal weight for time & environment',
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 8),
                  _buildRouteTypeCard(
                    icon: Icons.directions_car,
                    title: 'Normal Route',
                    description: 'Fastest route',
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle('App Features'),
                  const SizedBox(height: 12),
                  _buildFeatureList(),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Developers'),
                  const SizedBox(height: 12),
                  _buildDevelopersCard(),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Our Mission'),
                  const SizedBox(height: 12),
                  _buildMissionCard(),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Contact & Support'),
                  const SizedBox(height: 12),
                  _buildContactCard(),
                  const SizedBox(height: 24),
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'Version: 1.0.0',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Platform: Android | Release Year: 2026',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF43A047),
      ),
    );
  }

  Widget _buildContentCard({required String content}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // ignore: deprecated_member_use
        color: Colors.grey[900]!.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        content,
        style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
      ),
    );
  }

  Widget _buildRouteTypeCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // ignore: deprecated_member_use
        color: Colors.grey[900]!.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              // ignore: deprecated_member_use
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureList() {
    final features = [
      {'icon': Icons.calculate, 'text': 'Carbon footprint calculation'},
      {'icon': Icons.stars, 'text': 'Eco points reward system'},
      {'icon': Icons.ev_station, 'text': 'EV charging station suggestions'},
      {'icon': Icons.commute, 'text': 'Multi-modal transport comparison'},
      {'icon': Icons.air, 'text': 'Traffic and Air Quality visualization'},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // ignore: deprecated_member_use
        color: Colors.grey[900]!.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: features.map((feature) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(
                  feature['icon'] as IconData,
                  color: const Color(0xFF43A047),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    feature['text'] as String,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDevelopersCard() {
    final developers = [
      'MAHADEV O V',
      'Ashin Liju',
      'Basil Boban George',
      'Jithina V',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // ignore: deprecated_member_use
        color: Colors.grey[900]!.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Developed as a B.Tech Information Technology project focused on building smarter and greener urban mobility solutions.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ...developers.map(
            (dev) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.person, color: Color(0xFF43A047), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    dev,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMissionCard() {
    const Color brandGreen = Color(0xFF43A047);
    final missions = [
      '"Small travel choices today create a greener tomorrow."',
      '"Sustainability is not an option — it is our responsibility."',
      '"Every journey leaves a footprint. Choose the one that protects the Earth."',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF0A3D0A), Colors.grey[900]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        // ignore: deprecated_member_use
        border: Border.all(color: brandGreen.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.favorite, color: brandGreen, size: 20),
              SizedBox(width: 8),
              Text(
                '"To make every journey smarter, greener, and more sustainable."',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...missions.map(
            (mission) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                mission,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // ignore: deprecated_member_use
        color: Colors.grey[900]!.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'For feedback, suggestions, or technical support:',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              Icon(Icons.email, color: Color(0xFF43A047), size: 20),
              SizedBox(width: 8),
              Text(
                'way2sustain.offficial@gmail.com',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'We value your feedback and continuously work to improve sustainable travel solutions.',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
        ],
      ),
    );
  }
}
